# %%
import os
import pandas as pd
import geopandas as gpd
from pathlib import Path


# ### Inputs

# #### Network

# In[1]:


# network_load_path = os.path.join(
#     "..", "Source_Data", "Model_Output", "loaded_network.shp"
# )
# network_save_path = os.path.join("..", "Data", "Model_Output", "loaded_network.shp")


# # #### Ridership

# routes_path = os.path.join("..", "Source_Data", "Model_Output", "Transit_network")

# boards_load_path = os.path.join(routes_path, "ALL_BOARDINGS.DBF")
# ref_load_path = os.path.join(routes_path, "route_ref_new.csv")
# %%
# routes_load_path = os.path.join(routes_path, "ChattaTransit_2019_route.shp")
# routes_save_path = os.path.join("..", "Data", "Model_Output", "ridership.shp")
model_outputs_path = Path(r"C:\Users\USLP095001\Desktop\temp_files\3_Model_Output")
maps_save_dir = Path(
    r"C:\Users\USLP095001\Desktop\temp_files\chatt_outputs\map_save_dir"
)

network_load_path = model_outputs_path / "loaded_network.shp"
network_save_path = maps_save_dir / "loaded_network.shp"

# #### Ridership
routes_path = model_outputs_path / "Transit_network"

boards_load_path = routes_path / "ALL_BOARDINGS.DBF"
ref_load_path = routes_path / "route_ref_new.csv"

routes_load_path = routes_path / "ChattaTransit_2019_route.shp"
routes_save_path = maps_save_dir / "ridership.shp"

dtypes = {"ROUTE_ID": "str"}


# #### Trips


taz_path = os.path.join(
    "..", "Source_Data", "Districts_01252021", "TAZ_districts_Ext.shp"
)
xref_path = os.path.join("..", "Source_Data", "Districts_01252021", "xref_taz_ext.csv")

triptables_list = [
    "trip_tables",
    "tranist_trip_tables_AM",
    "tranist_trip_tables_PM",
    "tranist_trip_tables_OP",
    "Truck_OD",
]
triptable_load_path = os.path.join("..", "Source_Data", "Model_Output")
trips_save_path = os.path.join("..", "Data", "Model_Output", "trips.shp")

# %%


def load_trip_table(t, tloadpath):
    colnames = tt = list(
        pd.read_csv(os.path.join(tloadpath, f"{t}.dcc")).index.get_level_values(0)
    )
    tt = pd.read_csv(os.path.join(tloadpath, f"{t}.csv"), names=colnames)

    return tt


def build_map_files():
    network = gpd.read_file(network_load_path)

    ##### Ridership
    routes = gpd.read_file(routes_load_path, dtype=dtypes)
    boards = gpd.read_file(boards_load_path, dtype=dtypes)
    ref = gpd.read_file(ref_load_path, dtype=dtypes)

    routes = routes[["ROUTE_ID", "ROUTE_NAME", "geometry"]]
    routes = routes.astype(dtypes)
    ref = ref.astype(dtypes)

    ##### Trips
    taz = gpd.read_file(taz_path)
    # print(list(taz))
    taz = taz[["OBJECTID", "TAZ_Ext", "COUNTYID", "STATEID", "geometry"]].copy()

    tt = {}
    for t in triptables_list:
        tt[t] = load_trip_table(t, triptable_load_path)

    # ### Process Existing Conditions

    # #### Process Network Variables

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

    network.plot("C_SPEED")

    network[["AM_LOS", "PM_LOS", "VMT", "VHD", "C_SPEED", "FFSPEED"]].describe()

    # network["C_SPEED"].hist()

    # network["FFSPEED"].hist()

    # #### Process Ridership Variables

    route_boards = boards.copy()

    ##  17. Map: Transit Route Ridership (graduated color and bandwidth)
    route_boards = (
        boards.groupby(["ROUTE_ID", "ROUTE_NAME"])["AM_ON", "PM_ON", "OP_ON"]
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
    # route_boards = route_boards.groupby(['Route', 'Long Name'])['BOARDINGS'].sum().astype(int).reset_index()

    route_boards.plot("BOARDINGS")

    # #### Process Trips Variables

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
    taz_trips.plot("O_PASS")

    ##  19. Map: Origin of Transit Trips by TAZ (graduated color)
    trips = pd.concat([tt[f"tranist_trip_tables_{t}"] for t in ["AM", "PM", "OP"]])[
        ["Origin", "Local"]
    ]
    trips = trips.fillna(0).groupby("Origin").sum().reset_index()
    trips.columns = ["TAZID", "O_TRANSIT"]

    trips = pd.merge(trips, xref, on="TAZID", how="left")
    trips = trips.groupby("TAZ_Ext")["O_TRANSIT"].sum().reset_index()

    taz_trips = pd.merge(taz_trips, trips, on=tazcol, how="left")
    taz_trips.plot("O_TRANSIT")

    ##  20. Map: Origin of Truck Trips by TAZ (graduated color)
    trips = (
        tt["Truck_OD"].groupby("Row ID's")["Total_SUT", "Total_MUT"].sum().reset_index()
    )
    trips["TRUCKS"] = trips["Total_SUT"] + trips["Total_MUT"]
    trips = trips[["Row ID's", "TRUCKS"]]
    trips.columns = ["TAZID", "O_TRUCKS"]

    trips = pd.merge(trips, xref, on="TAZID", how="left")
    trips = trips.groupby("TAZ_Ext")["O_TRUCKS"].sum().reset_index()

    taz_trips = pd.merge(taz_trips, trips, on=tazcol, how="left")
    taz_trips.plot("O_TRUCKS")

    ## DESTINATION
    ##  21. Map: Destination of Passenger Vehicle Trips by TAZ (graduated color)
    trips = tt["trip_tables"].groupby("Destination")["PASS"].sum().reset_index()
    trips.columns = ["TAZID", "D_PASS"]

    trips = pd.merge(trips, xref, on="TAZID", how="left")
    trips = trips.groupby("TAZ_Ext")["D_PASS"].sum().reset_index()

    taz_trips = pd.merge(taz_trips, trips, on=tazcol, how="left")
    taz_trips.plot("D_PASS")

    ##  22. Map: Destination of Transit Trips by TAZ (graduated color)
    trips = pd.concat([tt[f"tranist_trip_tables_{t}"] for t in ["AM", "PM", "OP"]])[
        ["Destination", "Local"]
    ]
    trips = trips.fillna(0).groupby("Destination").sum().reset_index()
    trips.columns = ["TAZID", "D_TRANSIT"]

    trips = pd.merge(trips, xref, on="TAZID", how="left")
    trips = trips.groupby("TAZ_Ext")["D_TRANSIT"].sum().reset_index()

    taz_trips = pd.merge(taz_trips, trips, on=tazcol, how="left")
    taz_trips.plot("D_TRANSIT")

    ##  23. Map: Destination of Truck Trips by TAZ (graduated color)
    trips = (
        tt["Truck_OD"].groupby("Col ID's")["Total_SUT", "Total_MUT"].sum().reset_index()
    )
    trips["TRUCKS"] = trips["Total_SUT"] + trips["Total_MUT"]
    trips = trips[["Col ID's", "TRUCKS"]]
    trips.columns = ["TAZID", "D_TRUCKS"]

    trips = pd.merge(trips, xref, on="TAZID", how="left")
    trips = trips.groupby("TAZ_Ext")["D_TRUCKS"].sum().reset_index()

    taz_trips = pd.merge(taz_trips, trips, on=tazcol, how="left")
    taz_trips.plot("D_TRUCKS")

    # ### Checks

    network[["AM_LOS", "PM_LOS", "FFSPEED", "VMT", "VHD", "C_SPEED"]].describe()

    # ### Export Datasets

    # #### Network

    network.to_file(network_save_path, index=False)

    route_boards.to_file(routes_save_path, index=False)

    taz_trips.to_file(trips_save_path, index=False)


# %%
