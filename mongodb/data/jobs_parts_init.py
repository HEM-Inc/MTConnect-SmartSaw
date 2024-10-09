import pymongo


db_name = 'machine_objects'
client = pymongo.MongoClient('localhost', 27017)
collection_parts = client[db_name].parts
collection_parts.delete_many({})
print("Done initalizing the parts...")

collection_jobs = client[db_name].jobs
collection_jobs.delete_many({})
print("Done initalizing the parts...")
