# %%
import yaml
import pandas as pd
from pathlib import Path
import geopandas as gpd
from itertools import product
import os, shutil


def _saturation_to_los(degree_of_saturation: float, los_ranges):
    """
    calculates los from saturation and los_ranges
    """
    # unfortunately yml file reads in pair of numbers as a string
    # {}
    los_range_cleaned = {}
    try:
        for key, val_string in los_ranges.items():
            min_los, max_los = val_string.split(",")
            los_range_cleaned[key] = (float(min_los.strip()), float(max_los.strip()))
    except:
        raise Exception("Please check the that LOS_ranges in config.yml are correctly formatted")

    # check that whole range of saturation is covered, otherwise the user has made an error
    prev_max_los = 0
    for los, (min_los, max_los) in los_range_cleaned.items():
        if prev_max_los != min_los:
            raise Exception(f"in cofig.yml LOS_ranges, the min lf {los} is {min_los}, expected {prev_max_los}")
        
        prev_max_los = max_los
    
    for los, (min_los, max_los) in los_range_cleaned.items():
        if min_los <= degree_of_saturation < max_los:
            return los


# %%
def _get_link_lookups(link_lookup_directory: Path):
    all_links = []
    for specific_csv_path in link_lookup_directory.glob("*.csv"):
        specific_df = pd.read_csv(specific_csv_path)
        specific_df["Name"] = specific_df["Name"] + "_" + specific_csv_path.stem
        all_links.append(specific_df)

    return pd.concat(all_links)


def subset_catagories(
    model_output_path: Path,
    summary_output_path: Path,
    link_subsets: pd.DataFrame,
    config: dict,
):

    scenarios = config["scenario_impact"]["scenario"]
    agg_methods = config["scenario_impact"]["agg_methods"]
    los_ranges = config["scenario_impact"]["LOS_ranges"]
    
    # pandas.agg does not accept 'mode' as an input, replace with pd.mode
    for agg_column, method in agg_methods.items():
        if method == 'mode':
            agg_methods[agg_column] = lambda series: pd.Series.mode(series).iloc[0]

    list_link_subsets = [
        (scen_name, link_subsets[link_subsets["Name"] == scen_name])
        for scen_name in link_subsets["Name"].unique()
    ]
    for scen in scenarios:
        scen_str = str(scen)
        network_load_path = model_output_path / str(scen)

        network = gpd.read_file(network_load_path / "loaded_network.shp")

        for link_subset_name, link_subset_df in list_link_subsets:

            specific_output = summary_output_path / "scenario_impact"
            specific_output.mkdir(exist_ok=True)

            summary_subset = network[network["ID"].isin(link_subset_df["Link_ID"])]
            
            summary_table = {}
            summary_table["Speed Limit"] = summary_subset["SPD_LMT"].agg(agg_methods["SPEED"])
            summary_table["AB Lanes"] = summary_subset["AB_LANES"].agg(agg_methods["LANES"])
            summary_table["BA Lanes"] = summary_subset["BA_LANES"].agg(agg_methods["LANES"])

            summary_table["AM Peak Flow"] = summary_subset["AM_TOTFLOW"].agg(agg_methods["FLOW"])
            summary_table["PM Peak Flow"] = summary_subset["PM_TOTFLOW"].agg(agg_methods["FLOW"])
            summary_table["Off Peak Flow"] = summary_subset["OP_TOTFLOW"].agg(agg_methods["FLOW"])

            summary_table["Auto Daily Flow"] = summary_subset["TOT_AUTO"].agg(agg_methods["FLOW"])
            summary_table["Truck Daily Flow"] = (
                summary_subset["TOT_MUT"].agg(agg_methods["FLOW"]) + summary_subset["TOT_SUT"].agg(agg_methods["FLOW"])
            )
            summary_table["Total Daily Flow"] = summary_subset["TOTFLOW"].agg(agg_methods["FLOW"])
            

            summary_table["Daily Capacity"] = (
                f"{summary_subset['AB_DLYCAP'].agg(agg_methods['CAPACITY']):0.0f} - {summary_subset['BA_DLYCAP'].agg(agg_methods['CAPACITY']):0.0f}"
            )

            saturation = (
                summary_subset["TOTFLOW"]
                / (summary_subset["AB_DLYCAP"] + summary_subset["BA_DLYCAP"])
            ).mean()
            los = _saturation_to_los(saturation, los_ranges)
            summary_table["LOS (Lowest Level of Service)"] = (
                f"{saturation:0.3f} ({los})"
            )

            summary_table["Free Flow Time (seconds)"] = (
                summary_subset["FFTIME"].sum() * 60
            )

            summary_subset.loc[network["DIR"] == 0, "CTIME"] = (
                summary_subset["AB_CTIME"] + summary_subset["BA_CTIME"]
            ) / 2
            summary_subset.loc[summary_subset["DIR"].isin([-1, 1]), "CTIME"] = (
                summary_subset[["AB_CTIME", "BA_CTIME"]].max(axis=1)
            )
            summary_table["Congested Time (seconds)"] = (
                summary_subset["CTIME"].sum() * 60
            )

            summary_table["Free Flow Speed (MPH)"] = summary_subset["FFSPEED"].agg(agg_methods["SPEED"])

            summary_table["Congested Speed (MPH)"] = (
                summary_table["Free Flow Speed (MPH)"]
                * summary_table["Free Flow Time (seconds)"]
                / summary_table["Congested Time (seconds)"]
            )

            # TODO check CRS is in Meters
            summary_table["Vehicle Miles Traveled (VMT)"] = (
                summary_subset["LENGTH"] * summary_subset["TOTFLOW"]
            ).sum()

            summary_table["Vehicle Hours Delay (VHD)"] = ((
                (summary_subset["AB_CTIME"] - summary_subset["FFTIME"])
                * summary_subset["AB_TOTFLOW"]
                + (summary_subset["BA_CTIME"] - summary_subset["FFTIME"])
                * summary_subset["BA_TOTFLOW"]
            ) / 60).sum()

            summary_table = {key: [val] for key, val in summary_table.items()}
            pd.DataFrame.from_dict(summary_table).to_csv(
                specific_output / f"{scen_str}_{link_subset_name}.csv"
            )


def consolidate_one_report(summary_output_path: Path):

    all_tables = []
    for output_path in (summary_output_path / "scenario_impact").glob("*.csv"):
        temp_table = pd.read_csv(output_path)
        temp_table.insert(0, 'scenario', output_path.stem)
        all_tables.append(temp_table)

    shutil.rmtree(summary_output_path / "scenario_impact")
    pd.concat(all_tables).drop(columns="Unnamed: 0").round(2).to_csv(
        summary_output_path / "scenario_impact.csv", index=False
    )
