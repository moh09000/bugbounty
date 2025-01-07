import os
import subprocess
import re
from glob import glob
from concurrent.futures import ThreadPoolExecutor, as_completed
from concurrent.futures import ThreadPoolExecutor

# File paths
subdomains_file = "subdomains.txt"
http_file = "http.txt"
output_dir = "output_urls"
exclude_extensions = r"\.(css|jpg|png|jpeg|gif|svg|woff|woff2|ttf|ico)$"
num_threads = 10
# Check if subdomains file exists
if not os.path.isfile(subdomains_file):
    print("[-] File 'subdomains.txt' not found. Please provide a list of subdomains.")
    exit(1)

if not os.path.isfile(http_file):
    print("[-] File 'http_file' not found. Please provide it.")
    exit(1)

# Create output directory if it doesn't exist
os.makedirs(output_dir, exist_ok=True)
print(f"[+] Starting URL collection for subdomains in {subdomains_file}")
print(f"[+] Output directory: {output_dir}")

# Functions for running each tool

def run_gospider():
    print("[+] Running GoSpider...")
    try:
        subprocess.run(
            ["gospider", "-S", http_file, "-d", "2", "--include-subs", "--other-source", "--quiet", "-o", output_dir],
            check=True
        )
    except subprocess.CalledProcessError:
        print("[-] GoSpider failed.")

def run_hakrawler():
    print("[+] Running Hakrawler...")
    try:
        subprocess.run(
            ["hakrawler", "-d", "2", "-subs"],
            stdin=open(http_file, 'r'),
            stdout=open(f"{output_dir}/hakrawler_all.txt", "w"),
            stderr=subprocess.PIPE,
            check=True
        )
    except subprocess.CalledProcessError:
        print("[-] Hakrawler failed.")

def run_katana():
    print("[+] Running Katana...")
    try:
        subprocess.run(
            ["katana", "-list", subdomains_file, "-d", "3"],
            stdout=open(f"{output_dir}/katana_all.txt", "w"),
            stderr=subprocess.PIPE,
            check=True
        )
    except subprocess.CalledProcessError:
        print("[-] Katana failed.")

'''
def run_paramspider():
    print("[+] Running Paramspider...")
    try:
        subprocess.run(
            ["paramspider", "-l", subdomains_file],
            check=True
        )
    except subprocess.CalledProcessError:
        print("[-] Paramspider failed.")
'''

# Function to run Paramspider for a single subdomain
def run_paramspider():
    try:
        # Read subdomains from the file
        with open(subdomains_file, 'r') as file:
            subdomains = file.read().splitlines()
    except FileNotFoundError:
        print(f"[-] File '{subdomains_file}' not found.")
        return

    # Execute Paramspider for each subdomain
    for subdomain in subdomains:
        print(f"[+] Running Paramspider for {subdomain}...")
        try:
            subprocess.run(["paramspider", "-d", subdomain], check=True)
        except subprocess.CalledProcessError:
            print(f"[-] Paramspider failed for {subdomain}.")

# Run Paramspider concurrently
with ThreadPoolExecutor(max_workers=num_threads) as executor:
    # Create multiple workers, each reading the file and processing the subdomains
    executor.map(run_paramspider, range(num_threads))

print("[+] All tasks completed.")


print("[+] All tasks completed.")

# Run all the tools concurrently
with ThreadPoolExecutor(max_workers=4) as executor:
    # Schedule the tasks to run concurrently
    futures = [
        executor.submit(run_gospider),
        executor.submit(run_hakrawler),
        executor.submit(run_katana),
        executor.submit(run_paramspider)
    ]
    
    # Wait for all tasks to complete
    for future in as_completed(futures):
        pass  # Each future will execute in parallel, no need to handle individually

# Merge and filter URLs
print("[+] Merging and filtering URLs...")
all_urls = []
for file_path in glob(os.path.join(output_dir, "*")):
    with open(file_path, 'r') as file:
        all_urls.extend(file.readlines())

# Writing merged URLs to a file
with open(os.path.join(output_dir, "allurls.txt"), 'w') as all_file:
    all_file.writelines(all_urls)

# Filter URLs
with open(os.path.join(output_dir, "allurls.txt"), 'r') as all_file:
    filtered_urls = [url for url in all_file if not re.search(exclude_extensions, url)]

# Writing filtered URLs to a file
'''
with open(os.path.join(output_dir, "output_dir/filtered_urls.txt"), 'w') as filtered_file:
    filtered_file.writelines(filtered_urls)'''

print("[+] URL collection completed for all subdomains.")
