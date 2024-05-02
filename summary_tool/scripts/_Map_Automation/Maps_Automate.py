import os
import yaml
try:
    from yaml import CLoader as Loader, CDumper as Dumper
except ImportError:
    from yaml import Loader, Dumper

import sys
sys.path.append(r'C:\OSGeo4W\apps\qgis-ltr\python') # OK!

from qgis.core import *
from PyQt5.QtCore import *
from PyQt5.QtGui import *

qgs = QgsApplication([], False)
qgs.initQgis()

qgis_template = 'Chattanooga_Map_Deliverables.qgz'

map_def_file = os.path.join('..', 'config.yml')
logo_path = os.path.join('Data', 'rtp_logo.png')
export_path = os.path.join('..', 'summary_output')

p_size = 'Letter'
p_orient = QgsLayoutItemPage.Orientation.Portrait
map_size = [20, 20, 20, 20]
legend_title = "Legend"

## Load Map Definitions from YAML
# deliverables_yml1 = yaml.load(open(map_def_file), Loader=Loader)
deliverables_yml = yaml.load(open(map_def_file), Loader=Loader)['map_automation']
deliverables = deliverables_yml['maps']
## Base Layers
base_network = deliverables_yml['base_network']
base_taz = deliverables_yml['base_taz']
lay_off = deliverables_yml['layers_off_legend']
simple_legend = deliverables_yml['simple_legend']
l_ez_note = deliverables_yml['ez_note']


## Start Project instance and Layout Manager
project = QgsProject.instance()
project.read(qgis_template)
manager = project.layoutManager()

def drop_layout(l_long_name):
    ## Drop old version of Layout if exists
    layouts_list = manager.printLayouts()
    for layout in layouts_list:
        if layout.name()==l_long_name:
            manager.removeLayout(layout)

def add_layout(l_number, l_name, l_long_name, l_description, layers, layers_legend):
    ## Initialize Layout and add to Project
    layout = QgsPrintLayout(project)
    layout.initializeDefaults()
    
    pc = layout.pageCollection()
    pc.pages()[0].setPageSize('Letter', QgsLayoutItemPage.Orientation.Portrait)

    layout.setName(l_long_name)
    manager.addLayout(layout)
    
#    return layout

#def add_map(layout, layers):
    map = QgsLayoutItemMap(layout)
    map.setRect(*map_size)

    # set the map extent
    ms = QgsMapSettings()
    ms.setLayers(QgsProject.instance().mapLayersByName('TPO Boundary')) #TEST FIX
    map.setLayers(layers) #TEST DID IT
    
    rect = QgsRectangle(ms.fullExtent())
    rect.scale(1)
    ms.setExtent(rect)
    map.setExtent(rect)
    
    map.setBackgroundColor(QColor(255, 255, 255, 0))
    layout.addLayoutItem(map)

    map.attemptMove(QgsLayoutPoint(30, 2, QgsUnitTypes.LayoutMillimeters))
    map.attemptResize(QgsLayoutSize(180, 270, QgsUnitTypes.LayoutMillimeters))
    map.setScale(300000)
    
#    return map
    
#def add_title(layout, l_name):
    title = QgsLayoutItemLabel(layout)
    title.setText(l_name)
    title.setFont(QFont('Calibri', 24))
    title.setFixedSize(QgsLayoutSize(90, 30, QgsUnitTypes.LayoutMillimeters))
    title.setHAlign(Qt.AlignLeft)
    title.adjustSizeToText()
    layout.addLayoutItem(title)
    title.attemptMove(QgsLayoutPoint(10, 10, QgsUnitTypes.LayoutMillimeters))


    legend = QgsLayoutItemLegend(layout)

    layer_tree = QgsLayerTree()
    for layer in layers_legend:
        print(layer)
        layer_tree.addLayer(layer)
    legend.model().setRootGroup(layer_tree)
    
    layout.addLayoutItem(legend)
    legend.attemptMove(QgsLayoutPoint(10,45, QgsUnitTypes.LayoutMillimeters))
    
#def add_description(layout, l_description):
    description = QgsLayoutItemLabel(layout)
    description.setText(l_description)
    description.setFont(QFont('Calibri', 10))
    description.adjustSizeToText()
    description.setFixedSize(QgsLayoutSize(70, 60, QgsUnitTypes.LayoutMillimeters))
    layout.addLayoutItem(description)
    description.attemptMove(QgsLayoutPoint(10, 35, QgsUnitTypes.LayoutMillimeters))

    if 'ez_note' in meta and meta['ez_note']:
        note = QgsLayoutItemLabel(layout)
        note.setText(l_ez_note)
        note.setFont(QFont('Calibri', 10))
        note.adjustSizeToText()
        note.setFixedSize(QgsLayoutSize(70, 60, QgsUnitTypes.LayoutMillimeters))
        layout.addLayoutItem(note)
        note.attemptMove(QgsLayoutPoint(10, 250, QgsUnitTypes.LayoutMillimeters))
    
#def add_scalebar(layout, map):
    scalebar = QgsLayoutItemScaleBar(layout)
    scalebar.setStyle('Line Ticks Up')
    scalebar.setUnits(QgsUnitTypes.DistanceMiles)
    scalebar.setNumberOfSegments(2)
    scalebar.setNumberOfSegmentsLeft(0)
    scalebar.setUnitsPerSegment(5)
    scalebar.setLinkedMap(map)
    scalebar.setUnitLabel('Miles')
    scalebar.setFont(QFont('Calibri', 14))
    scalebar.update()
    layout.addLayoutItem(scalebar)
    scalebar.attemptMove(QgsLayoutPoint(10, 260, QgsUnitTypes.LayoutMillimeters))
    
    logo = QgsLayoutItemPicture(layout)
    # logo.setPicturePath(os.path.join('Data', 'rtp_logo.png'))
    logo.setPicturePath(logo_path)
    logo.attemptResize(QgsLayoutSize(60, 25))
    layout.addLayoutItem(logo)
    logo.attemptMove(QgsLayoutPoint(150, 250, QgsUnitTypes.LayoutMillimeters))
    

    exporter = QgsLayoutExporter(layout)
    exporter.exportToPdf(os.path.join(export_path, f'{l_number}.pdf'), QgsLayoutExporter.PdfExportSettings())
    print('\tMap exported to:', os.path.join(export_path, f'{l_number}.pdf'), '\n')
    
#def export_png(layout, l_number, export_path):
    # exporter = QgsLayoutExporter(layout)
    # exporter.exportToImage(os.path.join(export_path, f'{l_number}.png'), QgsLayoutExporter.ImageExportSettings())
    # print('\tMap exported to:', os.path.join(export_path, f'{l_number}.png'), '\n')
    
def generate_layout(d, meta):
    l_number = d
    l_name = meta['name']
    l_long_name = f'{l_number}: {l_name}'
    l_description = meta['description']
    
    ## Create Layers list
    base_layers = deliverables_yml[meta['base']]
    thematic_layers = meta['layers']
    layers = [b for t in base_layers for b in ([t] if t!='thematic_layers' else thematic_layers)]
    
    if simple_legend:
        layers_legend = [l for l in thematic_layers]
    else:
        layers_legend  = [t for t in thematic_layers] + [b for b in base_layers if b!='thematic_layers']
        layers_legend = [l for l in layers_legend  if l not in lay_off] 

    print('Processing Layout for', l_long_name)

    layers = [QgsProject.instance().mapLayersByName(l)[0] for l in layers]
    layers_legend = [QgsProject.instance().mapLayersByName(l)[0] for l in layers_legend]
    

    drop_layout(l_long_name)
    add_layout(l_number, l_name, l_long_name, l_description, layers, layers_legend)

for d, meta in deliverables.items():
    generate_layout(d, meta)


qgs.exitQgis()
print('Map Export Complete\n')

    
    
