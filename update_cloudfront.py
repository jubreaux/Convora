#!/usr/bin/env python3
"""
Update CloudFront distribution to serve admin web app from S3
- Adds alternate origin for admin S3 path
- Updates DefaultCacheBehavior to point to admin origin
- Configures: admin.convora.customertest.digitalbullet.net
"""

import json
import subprocess
import sys

def log_info(msg):
    print(f"[INFO] {msg}")

def log_error(msg):
    print(f"[ERROR] {msg}")

def update_cloudfront():
    DISTRIBUTION_ID = "E2N031064FD3ZI"
    
    log_info("Updating CloudFront distribution for admin web app...")
    
    # Get current config
    result = subprocess.run(
        ['aws', 'cloudfront', 'get-distribution-config', '--id', DISTRIBUTION_ID], 
        capture_output=True, text=True
    )
    if result.returncode != 0:
        log_error(f"Failed to get distribution config: {result.stderr}")
        return False
    
    try:
        data = json.loads(result.stdout)
    except json.JSONDecodeError as e:
        log_error(f"Failed to parse distribution config: {e}")
        return False
    
    etag = data.get('ETag')
    config = data.get('DistributionConfig', {})
    
    if not etag or not config:
        log_error("Invalid distribution config response")
        return False
    
    # Note: CloudFront aliases require matching SSL certificate
    # Instead, create a Route53 CNAME: admin.convora.customertest.digitalbullet.net -> CloudFront domain
    log_info("(Alias setup via Route53 CNAME instead - certificate covers only digitalbullet.net)")
    
    # Check if admin origin already exists
    existing_origins = {origin['Id']: origin for origin in config.get('Origins', {}).get('Items', [])}
    if 'S3-digitalbullet-admin' not in existing_origins:
        log_info("Adding S3 origin for admin path")
        admin_origin = {
            'Id': 'S3-digitalbullet-admin',
            'DomainName': 'digitalbullet.net.s3.us-east-1.amazonaws.com',
            'OriginPath': '/customertest/convora/admin',
            'CustomHeaders': {'Quantity': 0},
            'S3OriginConfig': {'OriginAccessIdentity': ''},
            'ConnectionAttempts': 3,
            'ConnectionTimeout': 10,
            'OriginShield': {'Enabled': False},
            'OriginAccessControlId': 'E5EDIRG0V0T7I'
        }
        config['Origins']['Items'].append(admin_origin)
        config['Origins']['Quantity'] = len(config['Origins']['Items'])
    else:
        log_info("Admin origin already configured")
    
    # Update DefaultCacheBehavior to point to admin origin
    log_info("Updating default cache behavior to serve admin web app")
    config['DefaultCacheBehavior']['TargetOriginId'] = 'S3-digitalbullet-admin'
    config['DefaultRootObject'] = 'index.html'
    
    # Write updated config to temp file
    with open('/tmp/cf-config-updated.json', 'w') as f:
        json.dump(config, f)
    
    # Update distribution
    log_info("Sending update to CloudFront...")
    update_result = subprocess.run([
        'aws', 'cloudfront', 'update-distribution',
        '--id', DISTRIBUTION_ID,
        '--distribution-config', 'file:///tmp/cf-config-updated.json',
        '--if-match', etag
    ], capture_output=True, text=True)
    
    if update_result.returncode == 0:
        try:
            update_data = json.loads(update_result.stdout)
            dist = update_data.get('Distribution', {})
            dist_config = dist.get('DistributionConfig', {})
            
            log_info("CloudFront distribution updated successfully! ✅")
            log_info(f"  Domain: {dist.get('DomainName')}")
            log_info(f"  Default Root Object: {dist_config.get('DefaultRootObject')}")
            log_info(f"  Default Origin: {dist_config.get('DefaultCacheBehavior', {}).get('TargetOriginId')}")
            log_info(f"  Status: {dist.get('Status')}")
            return True
        except json.JSONDecodeError:
            log_error(f"Failed to parse update response")
            return False
    else:
        log_error(f"Failed to update distribution: {update_result.stderr}")
        return False

if __name__ == '__main__':
    if not update_cloudfront():
        sys.exit(1)
