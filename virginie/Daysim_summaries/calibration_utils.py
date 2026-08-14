import os
import numpy as np
import pandas as pd
import re


#-------------- F12 file parsing and writing --------------
def _f12_float(s):
    try:
        return float(s)
    except ValueError:
        m = re.match(r'^([+-]?\d+\.?\d*)([+-]?\d+)$', s)
        if m:
            return float(m.group(1) + 'e' + m.group(2))
        raise


def _parse_f12_lines(path, skip=3):
    """Parse F12 file; return list of dicts with parsed data or raw lines."""
    records = []

    with open(path, "r") as fh:
        for i, raw in enumerate(fh):
            if i < skip:
                records.append({"is_data": False, "raw": raw})
                continue

            tokens = raw.split()
            try:
                if len(tokens) < 4:
                    raise ValueError

                # Keep only coefficient rows (e.g., '1 Beta00001 F -2.57 .48')
               # if not tokens[1].startswith("Beta"):
                #    raise ValueError("Not a coefficient row")
                if(len(tokens[2]) != 1 or not tokens[2].isalpha()):
                    raise ValueError("Not a coefficient row")

                records.append(
                    {
                        "is_data": True,
                        "end": int(tokens[0]),
                        "name": tokens[1],
                        "constr": tokens[2],
                        "beta": _f12_float(tokens[3]),
                        "raw": raw,
                    }
                )
            except (ValueError, IndexError):
                records.append({"is_data": False, "raw": raw})

    return records
   

def read_f12(path):
    """
    Read an F12 file from F12_DIR and return a DataFrame with columns:
        end, name, constr, beta, stderr
    One row per data line; non-data lines (headers, blanks) are excluded.
    Display this DataFrame to inspect the file contents.
    """
    records = _parse_f12_lines(path)
    df = pd.DataFrame(
        [{'end': r['end'], 'name': r['name'], 'constr': r['constr'],
          'beta': r['beta']}
         for r in records if r['is_data']]
    )
    return df

def find_token_pos(raw,token_index):
    pos,count = 0,0
    n = len(raw)
    while pos < n:
        while pos < n and raw[pos] in ' \t':
            pos += 1
        if pos >= n or raw[pos] in '\r\n':
            break
        start = pos
        while pos < n and raw[pos] not in ' \t\r\n':
            pos += 1
        if count == token_index:
            return start,pos
        count += 1
    return None,None

def _versioned_path(dir, filename):
    base, ext = os.path.splitext(filename)
    candidate = os.path.join(dir, filename)
    n = 2
    while os.path.exists(candidate):
        candidate = os.path.join(dir, f"{base}_{n}{ext}")
        n += 1
    return candidate

def write_f12(model_name, end_to_beta,f12_files, coefficient_input_dir, coefficient_interim_dir, copy_back=False):
    """
    Write an updated copy of the F12 file to F12_OUT_DIR.
    Reads from F12_DIR, replaces Beta at its exact character position for each
    END in end_to_beta, preserves all other content unchanged.
    """
    src_path = os.path.join(coefficient_input_dir , f12_files[model_name])
    interim_path = _versioned_path(coefficient_interim_dir , f12_files[model_name])
    os.makedirs(coefficient_interim_dir , exist_ok=True)

    out_lines = []
    n_updated = 0

    with open(src_path, 'r') as fh:
        for raw in fh:
            tokens = raw.split()
            try:
                end = int(tokens[0])
                if len(tokens) >= 4 and end in end_to_beta:
                    beta_start, beta_end = find_token_pos(raw, 3)
                    orig_width = beta_end - beta_start
                    new_beta_str = f'{end_to_beta[end]:.12f}'
                    if len(new_beta_str) < orig_width:
                        new_beta_str = new_beta_str.rjust(orig_width)
                    out_lines.append(raw[:beta_start] + new_beta_str + raw[beta_end:])
                    n_updated += 1
                    continue
            except (ValueError, IndexError):
                pass
            out_lines.append(raw)   
    dst_paths = [interim_path]
    if copy_back:
        dst_paths.append(src_path)
    for dst_path in dst_paths:
        with open(dst_path, 'w') as fh:
            fh.writelines(out_lines)
    print(f'  {f12_files[model_name]}: {n_updated} Beta(s) updated  ->  {dst_path}')

    if copy_back:
        print(f'  Original file {src_path} overwritten with updated Betas.')
    else:
        print(f' COPY_BACK is False: Original file {src_path} remains unchanged')


# Beta lookup
def load_beta_lookup(mapping_df, f12_files, coefficient_files_input_dir):
    """Build beta lookup from mapping dataframe and F12 files."""
    beta_lookup = {}
    for model in mapping_df['model'].unique():
        if model not in f12_files:
            print
            continue
        path = os.path.join(coefficient_files_input_dir , f12_files[model])
        beta_map = {
                r['end']: r['beta']
                for r in _parse_f12_lines(path)
                if r['is_data']
            }
        for _, row in mapping_df[mapping_df['model'] == model].iterrows():
            if pd.isna(row['end']):
                continue
            e = int(row['end'])
            vm = row.get('variable_mean',np.nan)
            #beta_lookup[(model, str(row['group']), str(row['alternative']))] = { 
            grp_key = '' if pd.isna(row['group']) else str(row['group'])
            beta_lookup[(model, grp_key, str(row['alternative']))] = { 
             'end': e, 
             'beta': beta_map.get(e, np.nan), 
             'variable_mean': 1.0 if pd.isna(vm) else float(vm)}
    return beta_lookup


# calibration helpers
def _ser(raw):
    """Helper to serialize return."""
    if isinstance(raw, pd.DataFrame):
        if 'psexpfac' in raw.columns:
            return raw['psexpfac']
        if raw.shape[1] == 1:
            return raw.iloc[:,0]
    return raw

def _get_raw(obj,method,method_arg):
    """Helper to get raw data for a given method and argument."""
    if method_arg:
        return getattr(obj, method)(method_arg)
    else:
        return getattr(obj, method)()

def _make_row(target, model, group, alt, csv_grp,csv_alt,mc_val,sc_val,m_tot,s_tot, beta_lookup,damping_factor,threshold):
    """Computes new beta."""
    m_pct = mc_val/ m_tot * 100 if m_tot > 0 else 0.0
    s_pct = sc_val/ s_tot * 100 if s_tot > 0 else 0.0
    diff = round(m_pct - s_pct, 2) # switched 7.16
    within = abs(diff) <= threshold
    print(repr((model, str(csv_grp), str(csv_alt))))
    entry = beta_lookup.get((model, str(csv_grp), str(csv_alt))) if csv_grp is not None else None
    end = entry['end'] if entry is not None else None
    current_beta = entry['beta'] if entry is not None else np.nan
    vm = entry['variable_mean'] if entry is not None else np.nan
    adj = round(damping_factor * np.log(s_pct / m_pct)/vm,4) if (
        entry and not within and m_pct > 0 and s_pct > 0) else 0.0
    new_beta = round(current_beta + adj, 4) if not np.isnan(current_beta) else np.nan

    return {
        'target': target, 
        'group':str(group), 
        'alternative': str(alt),
        'model_pct': round(m_pct,2),
        'survey_pct': round(s_pct,2),
        'diff': diff,
        'within_threshold': within,
        'calibrate': entry is not None,
        'current_beta': current_beta,
        'adjustment': adj,
        'new_beta': new_beta,
        'end': end,
        'variable_mean': vm,
        'model': model,
    }

def run_1d(target,model,m_raw,s_raw,beta_lookup,damping_factor,threshold,csv_key_fn=None):
    """Run D1 calibration for a single target/model."""
    mc, s = _ser(m_raw), _ser(s_raw)
    sc = s.reindex(mc.index, fill_value=0)
    m_tot = mc.sum()
    s_tot = sc.sum()
    rows = []
    for alt in mc.index:
        key = csv_key_fn(alt) if csv_key_fn else ('', alt)
        grp, a = key if key is not None else (None, None)
        print(repr(('run_id', alt, grp, a)))
        row = _make_row(target, model, '',alt, grp, a, 
                        float(mc[alt]), float(sc[alt]), m_tot, s_tot, 
                        beta_lookup, damping_factor, threshold)
        rows.append(row)

    return rows

def run_2d(target,model,m_raw,s_raw,beta_lookup,damping_factor,threshold):
    """Run D2 calibration for a single target/model."""
    rows = []
    for grp in m_raw.index:
        mc = m_raw.loc[grp]
        sc = s_raw.loc[grp].reindex(mc.index, fill_value=0) if grp in s_raw.index else pd.Series(0, index=mc.index)
        m_tot = mc.sum()
        s_tot = sc.sum()
        rows += [_make_row(target, model, grp, alt, str(grp), str(alt),
                          float(mc[alt]), float(sc[alt]), m_tot, s_tot, 
                          beta_lookup, damping_factor, threshold) 
                for alt in mc.index]

    return rows


def _make_csv_key_fn(key_mode,method_arg):
    """ create keys based on a specified group column."""
    if not key_mode:
        return None
    if key_mode.startswith('fixed_group:'):
        grp = key_mode.split(':', 1)[1]
        return lambda h, grp = grp: (grp, h)
    if key_mode == 'purpose_participation':
        p = method_arg
        return lambda a, p=p: ('',p) if a == 1 else None
    if key_mode == 'count_by_purpose':
        p = method_arg
        return lambda a, p=p: (p,a)
    raise ValueError(f'Unsupported key_mode: {key_mode!r}')


# Log
def save_log(comp_df, log_csv):

    cols = ['model', 'end','group','alternative', 'target','calibrate','within_threshold','survey_pct', 'model_pct', 'diff',  'current_beta', 'adjustment', 'new_beta']

    this_run = comp_df[[c for c in cols if c in comp_df.columns ]].copy()

    if os.path.exists(log_csv):
            existing = pd.read_csv(log_csv)
            if 'run' not in existing.columns:
                existing['run'] = 1
            max_run = existing['run'].max()
            run_n = int(max_run) + 1 if pd.notna(max_run) else 1
            keep = [c for c in existing.columns if c in this_run.columns or c == 'run']
            log_out = pd.concat([existing[keep], this_run.assign(run=run_n)[keep]], ignore_index=True)
    else:
            run_n = 1
            log_out = this_run.assign(run=run_n)
    
    logout = log_out[['run'] + [c for c in log_out.columns if c != 'run']]
    logout.to_csv(log_csv, index=False)
    print(f'Saved {log_csv} (run{run_n})')
