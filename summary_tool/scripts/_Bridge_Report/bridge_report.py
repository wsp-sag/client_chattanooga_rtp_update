import pandas as pd
import geopandas as gpd
import numpy as np
from pathlib import Path


# %%


# %%
def create_bridge_report(model_output_path, summary_output_path, scenario, county):
    network_df = pd.DataFrame()

    for scen in scenario:
        network_load_path = model_output_path / str(scen)
        network = gpd.read_file(network_load_path / "loaded_network.shp")
        network = network[
            [
                "COUNTY",
                "FUNCCLASS",
                "LENGTH",
                "TOTFLOW",
                "AB_TOTFLOW",
                "BA_TOTFLOW",
                "AB_CTIME",
                "BA_CTIME",
                "FFTIME",
                "DIR",
            ]
        ]

        # exclude non-motorized links, centroid connectors
        network = network[network["FUNCCLASS"] <= 7]
        network = network[network["COUNTY"].isin(county)]

        # vmt
        network["VMT"] = network["TOTFLOW"] * network["LENGTH"]
        # vhd
        network["VHD"] = (
            (network["AB_CTIME"] - network["FFTIME"]) * network["AB_TOTFLOW"]
            + (network["BA_CTIME"] - network["FFTIME"]) * network["BA_TOTFLOW"]
        ) / 60
        # congsted speed
        network.loc[network["DIR"] == 0, "CTIME"] = (
            network["AB_CTIME"] + network["BA_CTIME"]
        ) / 2
        network.loc[network["DIR"].isin([-1, 1]), "CTIME"] = network[
            ["AB_CTIME", "BA_CTIME"]
        ].max(axis=1)
        network["C_SPEED"] = network["LENGTH"] / (network["CTIME"] / 60)
        network["Scenario"] = scen

        network_df = pd.concat([network_df, network])

    vmt = (
        network_df.groupby(["FUNCCLASS", "COUNTY", "Scenario"])["VMT"]
        .sum()
        .reset_index()
        .pivot_table(
            index="FUNCCLASS",
            columns=["COUNTY", "Scenario"],
            values="VMT",
            aggfunc="sum",
            fill_value=0,
        )
    )

    vhd = (
        network_df.groupby(["FUNCCLASS", "COUNTY", "Scenario"])["VHD"]
        .sum()
        .reset_index()
        .pivot_table(
            index="FUNCCLASS",
            columns=["COUNTY", "Scenario"],
            values="VHD",
            aggfunc="sum",
            fill_value=0,
        )
    )

    c_speed_weighted = (
        network_df.groupby(["FUNCCLASS", "COUNTY", "Scenario"])
        .apply(lambda x: (x["C_SPEED"] * x["LENGTH"]).sum() / x["LENGTH"].sum())
        .reset_index(name="Weighted_C_SPEED")
        .pivot_table(
            index="FUNCCLASS",
            columns=["COUNTY", "Scenario"],
            values="Weighted_C_SPEED",
            aggfunc="mean",
            fill_value=0,
        )
    )

    c_speed = (
        network_df.groupby(["FUNCCLASS", "COUNTY", "Scenario"])["C_SPEED"]
        .mean()
        .reset_index()
        .pivot_table(
            index="FUNCCLASS",
            columns=["COUNTY", "Scenario"],
            values="C_SPEED",
            aggfunc="mean",
            fill_value=0,
        )
    )

    vmt.round(2).to_csv(
        summary_output_path / "RiverBridgeReport_VMT_by_FC_and_county.csv"
    )
    vhd.round(2).to_csv(
        summary_output_path / "RiverBridgeReport_VHD_by_FC_and_county.csv"
    )
    c_speed_weighted.round(2).to_csv(
        summary_output_path
        / "RiverBridgeReport_Weighted_CongSpeed_by_FC_and_county.csv"
    )
    c_speed.round(2).to_csv(
        summary_output_path / "RiverBridgeReport_CongSpeed_by_FC_and_county.csv"
    )


if __name__ == "__main__":

    create_bridge_report(MODEL_OUTPUT_PATH, SUMMARY_OUTPUT_PATH, SCENARIO, COUNTY)
