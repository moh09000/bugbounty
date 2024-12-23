#!/bin/bash

# ----------------------------
# Configuration Parameters
# ----------------------------
targets_list="./targets-list.txt"            # File containing the list of target domains
output_base_dir="./subdomain_recon"          # Base output directory for results
wordlist="/usr/share/seclists/Discovery/DNS/subdomains-top1million-20000.txt" # Wordlist for DNS Brute Force
resolvers_file="./resolvers.txt"             # Resolvers file for DNS tools (MassDNS)
massdns_bin="/usr/local/bin/massdns"         # Path to MassDNS binary
securitytrails_api_key="your_api_key_here"   # SecurityTrails API key
parallel_limit=5                             # Number of parallel processes
# ----------------------------

# Check if the targets list exists
if [ ! -f "$targets_list" ]; then
  echo "[-] Targets list not found: $targets_list"
  exit 1
fi

# Create base output directory
mkdir -p $output_base_dir

# ----------------------------
# Function: Process a single target
# ----------------------------
process_target() {
  target=$1
  echo "[+] Starting subdomain recon for: $target"

  # Create output directory for the current target
  output_dir="$output_base_dir/$target"
  mkdir -p $output_dir

  # ----------------------------
  # Step 1: Passive Recon
  # ----------------------------
  echo "[+] Passive Recon: Using Subfinder and Assetfinder..."
  (subfinder -d $target -silent -o - || true) >> $output_dir/subdomains_passive.txt
  (assetfinder --subs-only $target || true) >> $output_dir/subdomains_passive.txt

  echo "[+] Passive Recon: Using CertSpotter and Crt.sh..."
  (curl -s "https://crt.sh/?q=%25.$target&output=json" | jq -r '.[].name_value' | sed 's/\*\.//g' || true) >> $output_dir/subdomains_passive.txt

  echo "[+] Passive Recon: Using Wayback Machine..."
  (waybackurls $target | grep "\.$target" | sort -u || true) >> $output_dir/subdomains_passive.txt

  # ----------------------------
  # Step 2: Active Recon (DNS Brute Force)
  # ----------------------------
  echo "[+] Active Recon: DNS Brute Force using MassDNS..."
  if [ -f "$resolvers_file" ] && [ -f "$massdns_bin" ]; then
    massdns_output="$output_dir/massdns_results.txt"
    $massdns_bin -r $resolvers_file -t A -o S -w $massdns_output $wordlist
    cat $massdns_output | awk '{print $1}' | sed 's/\.$//' >> $output_dir/subdomains_active.txt
  else
    echo "[-] Skipping MassDNS (resolvers or binary not found)."
  fi

  # ----------------------------
  # Step 3: Extract CNAME Records
  # ----------------------------
  echo "[+] Extracting CNAME Records for $target..."
  cat $output_dir/subdomains_passive.txt $output_dir/subdomains_active.txt | sort -u | while read subdomain; do
    dig CNAME $subdomain +short | sed 's/\.$//' >> $output_dir/cname_records.txt
  done

  # ----------------------------
  # Step 4: Extract MX Records and Subdomains
  # ----------------------------
  echo "[+] Extracting MX Records for $target..."
  dig MX $target +short | awk '{print $2}' | while read mx_record; do
      echo $mx_record >> $output_dir/mx_records.txt
      # Extract subdomains from MX records if they belong to the target domain
      if [[ $mx_record == *$target ]]; then
          echo $mx_record >> $output_dir/subdomains_mx.txt
      fi
  done

  # ----------------------------
  # Step 5: API Integration
  # ----------------------------
  echo "[+] Active Recon: Using SecurityTrails API..."
  (curl -s "https://api.securitytrails.com/v1/domain/$target/subdomains?apikey=$securitytrails_api_key" | jq -r '.subdomains[]' | sed "s/$/.$target/" || true) >> $output_dir/subdomains_api.txt

  # ----------------------------
  # Step 6: Combine Results
  # ----------------------------
  echo "[+] Combining all subdomain results for $target and removing duplicates..."
  (cat $output_dir/subdomains_*.txt || true) | sort -u > $output_dir/all_subdomains.txt

  echo "[+] Subdomain Recon for $target complete. Results saved in: $output_dir/all_subdomains.txt"
}

export -f process_target
export output_base_dir wordlist resolvers_file massdns_bin securitytrails_api_key

# ----------------------------
# Process Targets in Parallel
# ----------------------------
echo "[+] Starting parallel processing of targets..."
cat $targets_list | xargs -P $parallel_limit -I {} bash -c 'process_target "$@"' _ {}
echo "[+] All targets processed. Results saved in: $output_base_dir"
