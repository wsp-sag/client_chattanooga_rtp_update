# Descirption
This folder contains The Scripts for processing the outputs of a ChattaModel. For deployment these scripts are compiled to a .exe file so the client can run without dealing with python dependencies ect.

# Build / Deployment
To create an exe file, use the pyinstaller ibrary on run_analysis.py

```
activate YOUR_ENVIRONMENT

cd path/to/repo/client_chattanooga_rtp_update/Scripts/

pyinstaller --onefile run_analysis.py
```

## Common Issues

If the build fails, you may need to upgrade pysintaller
```
conda update pyinstaller
```

If the build still fails, it may be useful to make the smallest viable environment contains all the packages. As of most recent writing:
```
conda install -n geopandas pandas PyYAML pyinstaller
```
# Usage
The exe created has the same behavior as running the run_analysis.py, this function will create a config file with cli prompts if a config.yml does not exist in the same directory. If the config.yml file exists, then the file will output the respective summaries according to the config.

