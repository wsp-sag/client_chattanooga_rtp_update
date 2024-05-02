import pandas as pd
from pathlib import Path
import geopandas as gpd


def subset_catagories(
    model_output_path: Path,
    summary_output_path: Path,
    scen: str,
    subset_name: str,
    subset_list: list[int],
):
    network_load_path = model_output_path / str(scen)
    network = gpd.read_file(network_load_path / "loaded_network.shp")

    specific_output = summary_output_path / "scenario_impact"
    specific_output.mkdir(exist_ok=True)

    summary_subset = network[network["ID"].isin(subset_list)]

    summary_table = {}
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

    summary_table["Daily Capacity"] = (
        f'{summary_subset["AB_DLYCAP"].mean():0.0f} - {summary_subset["BA_DLYCAP"].mean():0.0f}'
    )

    summary_table["FFTIME"] = (
        f'{summary_subset["AB_DLYCAP"].mean():1.0f} - {summary_subset["BA_DLYCAP"].mean():0.0f}'
    )

    summary_table["Free Flow Time (seconds)"] = summary_subset["FFTIME"].sum() * 60
    summary_table["Free Flow Speed (MPH)"] = summary_subset["FFSPEED"].mean()

    # TODO check CRS is in Meters
    summary_table["Vehicle Miles Traveled (VMT)"] = (
        summary_subset.length.sum() * summary_table["Daily Flow"]
    )
    print("Outputting: ", specific_output / f"{scen}_{subset_name}.csv")
    summary_table = {key: [val] for key, val in summary_table.items()}
    pd.DataFrame.from_dict(summary_table).to_csv(specific_output / "summary.csv")
