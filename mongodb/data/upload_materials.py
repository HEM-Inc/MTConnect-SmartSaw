import pymongo
import csv
import re

db_name = 'machine_objects'
client = pymongo.MongoClient('localhost', 27017)
collection_materials = client[db_name].materials

upload_materials(collection_materials)

def nwd(name):
    m = re.search(r'(.*?)\s*(\d+)\s+In', name)
    if m:
        return m.group(1)
    else:
        return name

def upload_materials(collection):
    with open('/etc/mongodb/data/MaterialLibrary.csv','r') as infile:
        reader = csv.DictReader(infile)
        for row in reader:
            print(row)
            collection.insert_one({
                'name':row['NAME'],
                'category':row['CLASS'],
                'diameter':float(row['SIZE']),
                'blade_speed':float(row['BLADE SPEED']),
                'chip_removal_rate':float(row['CHIP REMOVAL RATE']),
                'force':float(row['FORCE']),
                'name_without_diameter':nwd(row['NAME'])
            })
                
if __name__ == '__main__':
    client = pymongo.MongoClient('localhost', 27017)
    collection_materials = client['machine_objects'].materials
    collection_materials.delete_many({})
    upload_materials(collection_materials)
