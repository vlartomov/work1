import yaml

def filter_keys(data):
    """
    Filter out keys in the dictionaries that are not 'host' or 'name'.
    """
    new_data = []
    for entry in data:
        new_entry = {}
        if 'host' in entry:
            new_entry['host'] = entry['host']
        if 'name' in entry:
            new_entry['name'] = entry['name']
        if new_entry:
            new_data.append(new_entry)
    return new_data

if __name__ == '__main__':
    try:
        # Read the YAML file
        with open("zbx_export_hostss.yaml", 'r') as f:
            data = yaml.safe_load(f)
        
        print(f"Original Data: {data}")
        
        if not data:
            print("No data found in the YAML file.")
            exit(1)
        
        # Filter out unnecessary keys
        filtered_data = filter_keys(data)
        
        print(f"Filtered Data: {filtered_data}")
        
        # Write the filtered data back to a new YAML file
        with open("filtered_zbx_export_hostss.yaml", 'w') as f:
            yaml.safe_dump(filtered_data, f)
    
    except FileNotFoundError:
        print("The YAML file was not found.")
    except yaml.YAMLError as e:
        print(f"Error reading YAML file: {e}")






