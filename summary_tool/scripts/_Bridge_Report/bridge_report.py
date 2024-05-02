import pandas as pd
import geopandas as gpd
import numpy as np
from pathlib import Path


#%%
def subset_catagories(model_output_path, summary_output_path: Path, scen, subset_name, subset_list):
    network_load_path = model_output_path / str(scen)
    network = gpd.read_file(network_load_path / "loaded_network.shp")
    
    specific_output = summary_output_path / subset_name
    specific_output.mkdir(exist_ok=True)
    

    summary_subset = network[network["ID"].isin(subset_list)]
    

    summary_table = {} 
    summary_table["AM Peak Flow"] = summary_subset["AM_TOTFLOW"].mean()
    summary_table["PM Peak Flow"] = summary_subset["PM_TOTFLOW"].mean()
    summary_table["Off Peak flow"] = summary_subset["OP_TOTFLOW"].mean()

    summary_table["Auto Daily Flow"] = summary_subset["TOT_AUTO"].mean()
    summary_table["TRUCK Daily Flow"] = summary_subset["TOT_MUT"].mean() + summary_subset["TOT_SUT"].mean()
    summary_table["Daily Flow"] = summary_subset["TOTFLOW"].mean()

    summary_table["Daily Capacity"] = f'{summary_subset["AB_DLYCAP"].mean():0.0f} - {summary_subset["BA_DLYCAP"].mean():0.0f}'

    summary_table["Daily Capacity"] = f'{summary_subset["AB_DLYCAP"].mean():0.0f} - {summary_subset["BA_DLYCAP"].mean():0.0f}'

    summary_table["FFTIME"] = f'{summary_subset["AB_DLYCAP"].mean():1.0f} - {summary_subset["BA_DLYCAP"].mean():0.0f}'

    summary_table["Free Flow Time (seconds)"] = summary_subset["FFTIME"].sum() * 60
    summary_table["Free Flow Speed (MPH)"] = summary_subset["FFSPEED"].mean()

    # TODO check CRS is in Meters
    summary_table["Vehicle Miles Traveled (VMT)"] = summary_subset.length.sum() * summary_table["Daily Flow"]
    print("Outputting: ", specific_output / "summary.csv")
    summary_table = {key: [val] for key, val in summary_table.items()}
    pd.DataFrame.from_dict(summary_table).to_csv(specific_output / "summary.csv")






#%%
def create_bridge_report(model_output_path, summary_output_path, scenario, county):
    print(model_output_path)
    print(summary_output_path)
    network_df = pd.DataFrame()

    for scen in scenario:
        network_load_path = (model_output_path / str(scen))
        network = gpd.read_file(network_load_path / 'loaded_network.shp')
        network = network[['COUNTY','FUNCCLASS','LENGTH','TOTFLOW','AB_TOTFLOW','BA_TOTFLOW','AB_CTIME','BA_CTIME','FFTIME','DIR']]

        # exclude non-motorized links, centroid connectors
        network = network[network['FUNCCLASS']<=7]
        network = network[network['COUNTY'].isin(county)]

        # vmt
        network['VMT'] = network['TOTFLOW'] * network['LENGTH']
        # vhd
        network['VHD'] = ((network['AB_CTIME'] - network['FFTIME']) * network['AB_TOTFLOW'] +
                        (network['BA_CTIME'] - network['FFTIME']) * network['BA_TOTFLOW']
                        )/60
        # congsted speed
        network.loc[network['DIR']==0, 'CTIME'] = (network['AB_CTIME'] + network['BA_CTIME']) / 2
        network.loc[network['DIR'].isin([-1, 1]), 'CTIME'] = network[['AB_CTIME', 'BA_CTIME']].max(axis=1)
        network['C_SPEED'] = network['LENGTH'] / (network['CTIME'] / 60)
        network['Scenario'] = scen

        network_df = pd.concat([network_df, network])

    vmt = (network_df.groupby(['FUNCCLASS', 'COUNTY', 'Scenario'])['VMT']
        .sum()
        .reset_index()
        .pivot_table(index='FUNCCLASS', 
                        columns=['COUNTY','Scenario'], 
                        values='VMT', 
                        aggfunc='sum', 
                        fill_value=0)
        )

    vhd = (network_df.groupby(['FUNCCLASS', 'COUNTY', 'Scenario'])['VHD']
        .sum()
        .reset_index()
        .pivot_table(index='FUNCCLASS', 
                        columns=['COUNTY','Scenario'], 
                        values='VHD', 
                        aggfunc='sum', 
                        fill_value=0)
        )


    c_speed_weighted = (network_df.groupby(['FUNCCLASS', 'COUNTY', 'Scenario'])
        .apply(
        lambda x: (x['C_SPEED'] * x['LENGTH']).sum() / x['LENGTH'].sum())
        .reset_index(name='Weighted_C_SPEED')
        .pivot_table(index='FUNCCLASS', 
                        columns=['COUNTY','Scenario'], 
                        values='Weighted_C_SPEED', 
                        aggfunc='mean', 
                        fill_value=0)
        )

    c_speed = (network_df.groupby(['FUNCCLASS', 'COUNTY', 'Scenario'])['C_SPEED']
        .mean()
        .reset_index()
        .pivot_table(index='FUNCCLASS', 
                        columns=['COUNTY','Scenario'], 
                        values='C_SPEED', 
                        aggfunc='mean', 
                        fill_value=0)
        )
    
    vmt.round(2).to_csv(summary_output_path / 'RiverBridgeReport_VMT_by_FC_and_county.csv')
    vhd.round(2).to_csv(summary_output_path / 'RiverBridgeReport_VHD_by_FC_and_county.csv')
    c_speed_weighted.round(2).to_csv(summary_output_path / 'RiverBridgeReport_Weighted_CongSpeed_by_FC_and_county.csv')
    c_speed.round(2).to_csv(summary_output_path / 'RiverBridgeReport_CongSpeed_by_FC_and_county.csv')

if __name__ == "__main__":

    create_bridge_report(MODEL_OUTPUT_PATH, SUMMARY_OUTPUT_PATH, SCENARIO, COUNTY)
