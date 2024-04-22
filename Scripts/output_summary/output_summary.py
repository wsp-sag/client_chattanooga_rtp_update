# %%
import geopandas as gpd
import pandas as pd
import yaml
from pathlib import Path
import os

import logging

logging.basicConfig(
    level=logging.WARN, format="%(asctime)s - %(levelname)s - %(message)s"
)
cd = Path(os.getcwd())


def network_summary(network: gpd.GeoDataFrame) -> gpd.GeoDataFrame:
    ## Map12: AM Peak LOS (Volume/Capacity)
    # network['AM_LOS'] = (network['AB_AM_TOTF']+network['BA_AM_TOTF'])/(network['AB_AMCAP']+network['BA_AMCAP'])
    network["AM_LOS"] = network["AM_TOTFLOW"] / (
        network["AB_AMCAP"] + network["BA_AMCAP"]
    )

    ## Map13: PM Peak LOS (Volume/Capacity)
    # network['PM_LOS'] = (network['AB_PM_TOTF']+network['BA_PM_TOTF'])/(network['AB_PMCAP']+network['BA_PMCAP'])
    network["PM_LOS"] = network["PM_TOTFLOW"] / (
        network["AB_PMCAP"] + network["BA_PMCAP"]
    )

    ## Map14: VMT: Vehicle Miles Traveled
    network["VMT"] = network["TOTFLOW"] * network["LENGTH"]

    ## Map15: VHD: Vehicle hours of delay
    # network['VHD'] = ((network['CTIME'] - network['FFTIME']) / 60) * network['TOTFLOW']
    network["VHD"] = (
        (network["AB_CTIME"] - network["FFTIME"]) * network["AB_TOTFLOW"]
        + (network["BA_CTIME"] - network["FFTIME"]) * network["BA_TOTFLOW"]
    ) / 60

    ## Map16: Congested speeds
    ## Calculate Congested Time
    network.loc[network["DIR"] == 0, "CTIME"] = (
        network["AB_CTIME"] + network["BA_CTIME"]
    ) / 2
    network.loc[network["DIR"].isin([-1, 1]), "CTIME"] = network[
        ["AB_CTIME", "BA_CTIME"]
    ].max(axis=1)
    network["C_SPEED"] = network["LENGTH"] / (network["CTIME"] / 60)

    summary = network[
        ["AM_LOS", "PM_LOS", "VMT", "VHD", "C_SPEED", "FFSPEED"]
    ].describe()

    network_with_stats = network[["FFTIME", "CTIME", "VMT", "VHD", "TOTFLOW", "LENGTH"]]
    maxes = network_with_stats.max()
    sums = network_with_stats.sum()

    key_stats = sums.copy()
    key_stats["TOTFLOW"] = maxes["TOTFLOW"]
    key_stats = key_stats.to_frame().T.rename(columns={"TOTFLOW": "max_TOTFLOW"})
    return summary, network, key_stats


def summaries_transit_trip_table(
    trip_table: pd.DataFrame,
) -> tuple[pd.DataFrame, pd.DataFrame]:
    assert trip_table["Shuttle"].isna().all()
    origins = trip_table.groupby("Origin").agg({"Local": "sum"})
    destinations = trip_table.groupby("Destination").agg({"Local": "sum"})
    return origins, destinations


def get_origin_dest_totals(
    trip_table: pd.DataFrame,
) -> tuple[pd.DataFrame, pd.DataFrame]:
    return (
        trip_table.drop(columns="Destination").groupby("Origin").sum(),
        trip_table.drop(columns="Origin").groupby("Destination").sum(),
    )


def get_totals(
    trip_table: pd.DataFrame,
) -> tuple[pd.DataFrame, pd.DataFrame]:
    return trip_table.drop(columns=["Origin", "Destination"]).sum()


def summaries_trip_table(
    trip_table: pd.DataFrame,
) -> tuple[pd.DataFrame, pd.DataFrame]:
    origin_totals, dest_totals = get_origin_dest_totals(trip_table)
    totals = get_totals(trip_table)
    return totals, origin_totals, dest_totals


def summaries_model_outputs(model_path, summary_path):
    logging.info("Reading the network, this could take a while...")
    network = gpd.read_file(model_path / "loaded_network.shp")
    logging.info("done")

    network_nodes = gpd.read_file(model_path / "loaded_network_nodes.shp")
    csv_tables = dict()

    # Read outputs
    for file in model_path.glob("*.csv"):
        logging.info("reading {}".format(file))
        data_tables = pd.read_csv(file.with_suffix(".DCC"))
        col_names = data_tables.index.get_level_values(0)
        data = pd.read_csv(file, names=col_names)
        csv_tables[file.stem] = data

    logging.info("outputting tables in {}".format(summary_path))

    summary, processed_network, key_stats = network_summary(network)
    summary.to_csv(summary_path / "network_summary.csv")
    key_stats.to_csv(summary_path / "key_stats.csv")

    for tran_trip in [
        "tranist_trip_tables_AM",
        "tranist_trip_tables_OP",
        "tranist_trip_tables_PM",
    ]:
        ori, dest = summaries_transit_trip_table(csv_tables[tran_trip])
        ori.to_csv(summary_path / f"origin_sum_transit_{tran_trip[-2:]}.csv")
        dest.to_csv(summary_path / f"dest_sum_transit_{tran_trip[-2:]}.csv")

    for trip_name in ["trip_tables", "Truck_OD"]:
        totals, ori_tot, dest_total = summaries_trip_table(csv_tables[trip_name])
        file_name = "sum_total_trips" if trip_name != "Truck_OD" else "sum_truck_trips"
        totals.to_csv(summary_path / f"total_{trip_name}.csv")
        ori_tot.to_csv(summary_path / f"ori_{trip_name}.csv")
        dest_total.to_csv(summary_path / f"dest_{trip_name}.csv")


if __name__ == "__main__":
    with open(cd.parent / "config.yml") as f:
        config = yaml.safe_load(f)
    MODEL_OUTPUTS_PATH = Path(config["MODEL_OUTPUTS"])
    SUMMARY_OUTPUT_PATH = Path(config["SUMMARY_OUTPUTS"])
    summaries_model_outputs(MODEL_OUTPUTS_PATH, SUMMARY_OUTPUT_PATH)
