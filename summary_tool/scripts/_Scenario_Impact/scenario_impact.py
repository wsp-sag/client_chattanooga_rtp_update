# %%
import pandas as pd
from pathlib import Path
import geopandas as gpd
from itertools import product
import os, shutil


def _saturation_to_los(saturation: float, num_lanes=4):
    """
    calculates LOS according to https://ccag.ca.gov/wp-content/uploads/2014/07/cmp_2005_Appendix_B.pdf
    """
    if num_lanes == 4:
        breaks = [0, 0.318, 0.509, 0.747, 0.916, 1]
    else:
        raise NotImplementedError()
    alphabet_iter = iter("abcdefghijklmnopqrstuvwxyz")
    for start, end, alpha in zip(breaks[0:-1], breaks[1:], alphabet_iter):
        if start <= saturation < end:
            return alpha

    return next(alphabet_iter)


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
    scenarios: list[int],
    network=None,
):
    list_link_subsets = [
        (scen_name, link_subsets[link_subsets["Name"] == scen_name])
        for scen_name in link_subsets["Name"].unique()
    ]
    for scen in scenarios:
        scen_str = str(scen)
        network_load_path = model_output_path / str(scen)

        if network is None:
            network = gpd.read_file(network_load_path / "loaded_network.shp")

        for link_subset_name, link_subset_df in list_link_subsets:

            specific_output = summary_output_path / "scenario_impact"
            specific_output.mkdir(exist_ok=True)

            summary_subset = network[network["ID"].isin(link_subset_df["Link_ID"])]

            summary_table = {}
            summary_table["Average Speed Limit"] = summary_subset["SPD_LMT"].mean()
            summary_table["Average AB Lanes"] = summary_subset["AB_LANES"].mean()
            summary_table["Average BA Lanes"] = summary_subset["BA_LANES"].mean()

            summary_table["AM Peak Flow"] = summary_subset["AM_TOTFLOW"].mean()
            summary_table["PM Peak Flow"] = summary_subset["PM_TOTFLOW"].mean()
            summary_table["Off Peak flow"] = summary_subset["OP_TOTFLOW"].mean()

            summary_table["Auto Daily Flow"] = summary_subset["TOT_AUTO"].mean()
            summary_table["Truck Daily Flow"] = (
                summary_subset["TOT_MUT"].mean() + summary_subset["TOT_SUT"].mean()
            )
            summary_table["Total Daily Flow"] = summary_subset["TOTFLOW"].mean()

            summary_table["Daily Capacity"] = f"{summary_subset["AB_DLYCAP"].mean():0.0f} - {summary_subset["BA_DLYCAP"].mean():0.0f}"
            

            saturation = (
                summary_subset["TOTFLOW"] / (summary_subset["AB_DLYCAP"] + summary_subset["BA_DLYCAP"])
            ).mean()
            los = _saturation_to_los(saturation)
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

            summary_table["Free Flow Speed (MPH)"] = summary_subset["FFSPEED"].mean()

            summary_table["Congested Speed (MPH)"] = (
                summary_table["Free Flow Speed (MPH)"]
                * summary_table["Free Flow Time (seconds)"]
                / summary_table["Congested Time (seconds)"]
            )

            # TODO check CRS is in Meters
            summary_table["Vehicle Miles Traveled (VMT)"] = (
                summary_subset["LENGTH"].sum() * summary_table["Total Daily Flow"]
            )

            summary_table["Vehicle Hours Delay (VHD)"] = (
                (summary_subset["AB_CTIME"] - summary_subset["FFTIME"])
                * summary_subset["AB_TOTFLOW"]
                + (summary_subset["BA_CTIME"] - summary_subset["FFTIME"])
                * summary_subset["BA_TOTFLOW"]
            ) / 60

            summary_table = {key: [val] for key, val in summary_table.items()}
            pd.DataFrame.from_dict(summary_table).to_csv(
                specific_output / f"{scen_str}_{link_subset_name}.csv"
            )


def consolidate_one_report(summary_output_path: Path):

    all_tables = []
    for output_path in (summary_output_path / "scenario_impact").glob("*.csv"):
        temp_table = pd.read_csv(output_path)
        temp_table["scenario"] = output_path.stem
        all_tables.append(temp_table)

    shutil.rmtree(summary_output_path / "scenario_impact")
    pd.concat(all_tables).drop(columns="Unnamed: 0").to_csv(
        summary_output_path / "scenario_impact.csv", index=False
    )
