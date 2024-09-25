import os
import pandas as pd
import geopandas as gpd
from pathlib import Path


def load_trip_table(t, triptable_load_path):
    colnames = tt = list(
        pd.read_csv(os.path.join(triptable_load_path, f"{t}.dcc"),skiprows=1).index.get_level_values(0)
    )
    tt = pd.read_csv(os.path.join(triptable_load_path, f"{t}.csv"), names=colnames)

    return tt



def model_output_postprocess(model_outputs_path,maps_data_path,maps_save_dir,scenario,LOOKUP):

    network_load_path = model_outputs_path /  scenario  / "loaded_network.shp"
    network_save_path = maps_save_dir / "loaded_network.shp"

    ### Ridership
    boards_load_path =  model_outputs_path /  scenario /  "ALL_BOARDINGS.DBF"
    ref_load_path =  LOOKUP / "route_ref_new.csv"

    routes_load_path =  model_outputs_path /  scenario /  "ChattaTransit_route.shp"
    routes_save_path = maps_save_dir / "ridership.shp"

    taz_path = maps_data_path / "Districts_01252021" / "TAZ_districts_Ext.shp"

    xref_path = maps_data_path / "Districts_01252021" / "xref_taz_ext.csv"
    
    triptables_list = [
        "trip_tables",
        "tranist_trip_tables_AM",
        "tranist_trip_tables_PM",
        "tranist_trip_tables_OP",
        "Truck_OD",
    ]
    triptable_load_path = model_outputs_path / scenario
    trips_save_path = maps_save_dir / 'trips.shp'

    dtypes = {"ROUTE_ID": "str"}

    network = gpd.read_file(network_load_path)
    
    ### Ridership
    routes = gpd.read_file(routes_load_path, dtype=dtypes)
    boards = gpd.read_file(boards_load_path, dtype=dtypes)
    ref = gpd.read_file(ref_load_path, dtype=dtypes)

    routes = routes[["ROUTE_ID", "ROUTE_NAME", "geometry"]]
    routes = routes.astype(dtypes)
    ref = ref.astype(dtypes)

    ### Trips
    taz = gpd.read_file(taz_path)
    taz = taz[["OBJECTID", "TAZ_Ext", "COUNTYID", "STATEID", "geometry"]].copy()

    tt = {}
    for t in triptables_list:
        tt[t] = load_trip_table(t, triptable_load_path)
    
    
    ### Process Existing Conditions
    ### Process Network Variables

    ## Map12: AM Peak LOS (Volume/Capacity)
    network["AM_LOS"] = network["AM_TOTFLOW"] / (
        network["AB_AMCAP"] + network["BA_AMCAP"]
    )

    ## Map13: PM Peak LOS (Volume/Capacity)
    network["PM_LOS"] = network["PM_TOTFLOW"] / (
        network["AB_PMCAP"] + network["BA_PMCAP"]
    )

    ## Map14: VMT: Vehicle Miles Traveled
    network["VMT"] = network["TOTFLOW"] * network["LENGTH"]

    ## Map15: VHD: Vehicle hours of delay
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

    
    ### Process Ridership Variables
    route_boards = boards.copy()

    ##  17. Map: Transit Route Ridership (graduated color and bandwidth)
    route_boards = (
        boards.groupby(["ROUTE_ID", "ROUTE_NAME"])[["AM_ON", "PM_ON", "OP_ON"]]
        .sum()
        .reset_index()
    )
    route_boards = route_boards.astype(dtypes)
    route_boards["BOARDINGS"] = (
        route_boards["AM_ON"] + route_boards["PM_ON"] + route_boards["OP_ON"]
    ).astype(int)

    route_boards = pd.merge(
        routes, route_boards[["ROUTE_ID", "BOARDINGS"]], on="ROUTE_ID", how="left"
    )
    route_boards = route_boards.astype(dtypes)
    route_boards = pd.merge(
        route_boards, ref[["ROUTE_ID", "Route", "Long Name"]], on="ROUTE_ID", how="left"
    )
    route_boards["Route_Name"] = (
        route_boards["Route"] + ": " + route_boards["Long Name"]
    )

    ### Process Trips Variables

    xref = pd.read_csv(xref_path)
    xref = xref[["TAZID", "TAZ_Ext"]].copy()

    tazcol = "TAZ_Ext"
    taz_trips = taz.copy()

    ## ORIGIN
    ##  18. Map: Origin of Passenger Vehicle Trips by TAZ (graduated color)
    trips = tt["trip_tables"].groupby("Origin")["PASS"].sum().reset_index()
    trips.columns = ["TAZID", "O_PASS"]

    trips = pd.merge(trips, xref, on="TAZID", how="left")
    trips = trips.groupby("TAZ_Ext")["O_PASS"].sum().reset_index()

    taz_trips = pd.merge(taz_trips, trips, on=tazcol, how="left")

    ##  19. Map: Origin of Transit Trips by TAZ (graduated color)
    trips = pd.concat([tt[f"tranist_trip_tables_{t}"] for t in ["AM", "PM", "OP"]])[
        ["Origin", "Local"]
    ]
    trips = trips.fillna(0).groupby("Origin").sum().reset_index()
    trips.columns = ["TAZID", "O_TRANSIT"]

    trips = pd.merge(trips, xref, on="TAZID", how="left")
    trips = trips.groupby("TAZ_Ext")["O_TRANSIT"].sum().reset_index()

    taz_trips = pd.merge(taz_trips, trips, on=tazcol, how="left")

    ##  20. Map: Origin of Truck Trips by TAZ (graduated color)
    trips = (
        tt["Truck_OD"]
        .groupby("Row ID's")[["Total_SUT", "Total_MUT"]]
        .sum()
        .reset_index()
    )
    trips["TRUCKS"] = trips["Total_SUT"] + trips["Total_MUT"]
    trips = trips[["Row ID's", "TRUCKS"]]
    trips.columns = ["TAZID", "O_TRUCKS"]

    trips = pd.merge(trips, xref, on="TAZID", how="left")
    trips = trips.groupby("TAZ_Ext")["O_TRUCKS"].sum().reset_index()

    taz_trips = pd.merge(taz_trips, trips, on=tazcol, how="left")

    ## DESTINATION
    ##  21. Map: Destination of Passenger Vehicle Trips by TAZ (graduated color)
    trips = tt["trip_tables"].groupby("Destination")["PASS"].sum().reset_index()
    trips.columns = ["TAZID", "D_PASS"]

    trips = pd.merge(trips, xref, on="TAZID", how="left")
    trips = trips.groupby("TAZ_Ext")["D_PASS"].sum().reset_index()

    taz_trips = pd.merge(taz_trips, trips, on=tazcol, how="left")

    ##  22. Map: Destination of Transit Trips by TAZ (graduated color)
    trips = pd.concat([tt[f"tranist_trip_tables_{t}"] for t in ["AM", "PM", "OP"]])[
        ["Destination", "Local"]
    ]
    trips = trips.fillna(0).groupby("Destination").sum().reset_index()
    trips.columns = ["TAZID", "D_TRANSIT"]

    trips = pd.merge(trips, xref, on="TAZID", how="left")
    trips = trips.groupby("TAZ_Ext")["D_TRANSIT"].sum().reset_index()

    taz_trips = pd.merge(taz_trips, trips, on=tazcol, how="left")

    ##  23. Map: Destination of Truck Trips by TAZ (graduated color)
    trips = (
        tt["Truck_OD"]
        .groupby("Col ID's")[["Total_SUT", "Total_MUT"]]
        .sum()
        .reset_index()
    )
    trips["TRUCKS"] = trips["Total_SUT"] + trips["Total_MUT"]
    trips = trips[["Col ID's", "TRUCKS"]]
    trips.columns = ["TAZID", "D_TRUCKS"]

    trips = pd.merge(trips, xref, on="TAZID", how="left")
    trips = trips.groupby("TAZ_Ext")["D_TRUCKS"].sum().reset_index()

    taz_trips = pd.merge(taz_trips, trips, on=tazcol, how="left")


    network.to_file(network_save_path, index=False, crs='EPSG:4019')

    route_boards.to_file(routes_save_path, index=False, crs='EPSG:4019')

    taz_trips.to_file(trips_save_path, index=False, crs='EPSG:4019')
