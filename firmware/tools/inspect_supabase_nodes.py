import requests
import json

url = 'https://dqnmxlljqiqgqmntzvcx.supabase.co/rest/v1/nodes?select=*'
headers = {
    'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRxbm14bGxqcWlxZ3FtbnR6dmN4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYyNjQwMzIsImV4cCI6MjEwMTg0MDAzMn0.RBcHQxjlZy3Cv-57gaRwM_BISoYaFJfTfJs9kxTLT7w',
    'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRxbm14bGxqcWlxZ3FtbnR6dmN4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYyNjQwMzIsImV4cCI6MjEwMTg0MDAzMn0.RBcHQxjlZy3Cv-57gaRwM_BISoYaFJfTfJs9kxTLT7w'
}

r = requests.get(url, headers=headers)
nodes = r.json()
print(f'Total nodes: {len(nodes)}')
for n in sorted(nodes, key=lambda x: x['node_id']):
    print(f"ID: {n['node_id']} | level: {n.get('level_id')} | name: {n.get('name_ar')} | x: {n.get('x')}, y: {n.get('y')}")

# Also fetch destinations
r_dest = requests.get('https://dqnmxlljqiqgqmntzvcx.supabase.co/rest/v1/destinations?select=*', headers=headers)
destinations = r_dest.json()
print(f'\nTotal destinations: {len(destinations)}')
for d in destinations:
    print(f"Dest ID: {d.get('id')} | node_id: {d.get('node_id')} | name: {d.get('name_ar')}")
