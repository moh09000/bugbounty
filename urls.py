#!/usr/bin/env python3
import subprocess
import argparse
import os
import re
from concurrent.futures import ThreadPoolExecutor
from urllib.parse import urlparse, parse_qs, urlencode

# Configuration
BLOCKED_EXTENSIONS = [".jpg", ".jpeg", ".png", ".gif", ".svg", ".css", ".js", ".woff", ".pdf"]
PARAM_PLACEHOLDER = "FUZZ"

def run_command(command):
    try:
        result = subprocess.run(command, shell=True, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        return result.stdout.strip().split('\n')
    except subprocess.CalledProcessError as e:
        print(f"Error running command: {command}\n{e.stderr}")
        return []

def filter_urls(urls):
    """Filter out URLs with blocked extensions."""
    return [url for url in urls if not any(ext in url.lower() for ext in BLOCKED_EXTENSIONS)]

def clean_params(url):
    """Replace all parameter values with FUZZ."""
    parsed = urlparse(url)
    if not parsed.query:
        return None  # Skip URLs without parameters
    
    # Replace all parameter values
    params = parse_qs(parsed.query)
    clean_params = {k: [PARAM_PLACEHOLDER] for k in params}
    clean_query = urlencode(clean_params, doseq=True)
    
    return parsed._replace(query=clean_query).geturl()

def run_gau(subdomains_file):
    return run_command(f"cat {subdomains_file} | gau | grep -Ev '\\.({'|'.join(BLOCKED_EXTENSIONS)})'")

def run_waybackurls(subdomains_file):
    return run_command(f"cat {subdomains_file} | waybackurls | grep -Ev '\\.({'|'.join(BLOCKED_EXTENSIONS)})'")

def run_katana(subdomains_file):
    return run_command(f"katana -list {subdomains_file} -jc -kf -d 3 -silent | grep -Ev '\\.({'|'.join(BLOCKED_EXTENSIONS)})'")

def process_tools(subdomains_file, output_dir):
    print("[+] Running tools in parallel...")

    with ThreadPoolExecutor(max_workers=3) as executor:
        gau_future = executor.submit(run_gau, subdomains_file)
        wayback_future = executor.submit(run_waybackurls, subdomains_file)
        katana_future = executor.submit(run_katana, subdomains_file)

        # Get and filter URLs
        gau_urls = filter_urls(gau_future.result())
        wayback_urls = filter_urls(wayback_future.result())
        katana_urls = filter_urls(katana_future.result())

    # Combine, deduplicate, and process parameters
    all_urls = set(gau_urls + wayback_urls + katana_urls)
    param_urls = []
    
    for url in all_urls:
        cleaned = clean_params(url)
        if cleaned:
            param_urls.append(cleaned)
    
    print(f"[+] Found {len(param_urls)} parameterized URLs (after cleaning).")

    # Save to file
    output_file = os.path.join(output_dir, "param_urls.txt")
    with open(output_file, 'w') as f:
        f.write('\n'.join(param_urls))
    
    print(f"[+] Saved parameterized URLs to: {output_file}")

def main():
    parser = argparse.ArgumentParser(description="Parallel URL extraction with parameter cleaning")
    parser.add_argument("-l", "--list", required=True, help="File containing subdomains (one per line)")
    parser.add_argument("-o", "--output", default="param_results", help="Output directory")
    args = parser.parse_args()

    if not os.path.exists(args.output):
        os.makedirs(args.output)

    process_tools(args.list, args.output)

if __name__ == "__main__":
    main()