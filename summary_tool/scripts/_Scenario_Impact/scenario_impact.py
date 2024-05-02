# %%
import pandas as pd
from pathlib import Path
import geopandas as gpd


def _saturation_to_los(saturation: float, num_lanes=4):
    """
    calculates LOS according to https://ccag.ca.gov/wp-content/uploads/2014/07/cmp_2005_Appendix_B.pdf
    """
    if num_lanes == 4:
        breaks = [0, 0.318, 0.509, 0.747, 0.916, 1]
    else:
        raise NotImplementedError()
    alphabet_iter = iter("abcdefghijklmnopqrstuvwkyz")
    for start, end, alpha in zip(breaks[0:-1], breaks[1:], alphabet_iter):
        if start <= saturation < end:
            return alpha

    return next(alphabet_iter)


# %%


def subset_catagories(
    model_output_path: Path,
    summary_output_path: Path,
    scen: str,
    subset_name: str,
    subset_list: list[int],
    network=None,
):
    network_load_path = model_output_path / str(scen)
    if network is None:
        network = gpd.read_file(network_load_path / "loaded_network.shp")

    specific_output = summary_output_path / "scenario_impact"
    specific_output.mkdir(exist_ok=True)

    summary_subset = network[network["ID"].isin(subset_list)]

    summary_table = {}
    summary_table["Average Speed Limit"] = summary_subset["SPD_LMT"].mean()
    summary_table["Average AB Lanes"] = summary_subset["AB_TOTFLOW"].mean()
    summary_table["Average AB Lanes"] = summary_subset["BA_TOTFLOW"].mean()

    summary_table["AM Peak Flow"] = summary_subset["AM_TOTFLOW"].mean()
    summary_table["PM Peak Flow"] = summary_subset["PM_TOTFLOW"].mean()
    summary_table["Off Peak flow"] = summary_subset["OP_TOTFLOW"].mean()

    summary_table["Auto Daily Flow"] = summary_subset["TOT_AUTO"].mean()
    summary_table["TRUCK Daily Flow"] = (
        summary_subset["TOT_MUT"].mean() + summary_subset["TOT_SUT"].mean()
    )
    summary_table["Daily Flow"] = summary_subset["TOTFLOW"].mean()

    summary_table["Daily Capacity"] = (
        f'{summary_subset["AB_DLYCAP"].mean():0.0f} - {summary_subset["BA_DLYCAP"].mean():0.0f}'
    )

    saturation = (
        network["TOTFLOW"] / (network["AB_DLYCAP"] + network["BA_DLYCAP"])
    ).mean()
    los = _saturation_to_los(saturation)
    summary_table["LOS (Lowest Level of Service)"] = f"{saturation:0.3f} ({los})"

    summary_table["Free Flow Time (seconds)"] = summary_subset["FFTIME"].sum() * 60

    summary_subset.loc[network["DIR"] == 0, "CTIME"] = (
        summary_subset["AB_CTIME"] + summary_subset["BA_CTIME"]
    ) / 2
    summary_subset.loc[summary_subset["DIR"].isin([-1, 1]), "CTIME"] = summary_subset[
        ["AB_CTIME", "BA_CTIME"]
    ].max(axis=1)
    summary_table["Congested Time (seconds)"] = summary_subset["CTIME"].sum() * 60

    summary_table["Free Flow Speed (MPH)"] = summary_subset["FFSPEED"].mean()

    summary_table["Congested Speed (MPH)"] = (
        summary_table["Free Flow Speed (MPH)"]
        * summary_table["Congested Time (seconds)"]
        / summary_table["Free Flow Time (seconds)"]
    )

    # TODO check CRS is in Meters
    summary_table["Vehicle Miles Traveled (VMT)"] = (
        summary_subset["LENGTH"] * summary_table["Daily Flow"]
    )
    print("Outputting: ", specific_output / f"{scen}_{subset_name}.csv")
    summary_table = {key: [val] for key, val in summary_table.items()}
    pd.DataFrame.from_dict(summary_table).to_csv(
        specific_output / f"{scen}_{subset_name}.csv"
    )


def consolidate_one_report(summary_output_path):

    all_tables = []
    for output_path in (summary_output_path / "scenario_impact").glob("*.csv"):
        all_tables.append(pd.read_csv(output_path))

    pd.concat(all_tables).to_csv(summary_output_path / "scenario_impact.csv")
