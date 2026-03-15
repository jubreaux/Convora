#!/usr/bin/env python3
"""
Create Route53 DNS record for admin subdomain pointing to CloudFront
Maps: admin.convora.customertest.digitalbullet.net -> CloudFront distribution
"""

import json
import subprocess
import sys

def log_info(msg):
    print(f"[INFO] {msg}")

def log_error(msg):
    print(f"[ERROR] {msg}")

def create_route53_record():
    HOSTED_ZONE_ID = "Z01476513T5NXK9JIVQ3T"
    DOMAIN_NAME = "admin.convora.customertest.digitalbullet.net"
    CLOUDFRONT_DOMAIN = "d104kiv4j1ijg7.cloudfront.net"
    
    log_info("Creating Route53 DNS record for admin subdomain...")
    
    # Check if record already exists
    result = subprocess.run(
        ['aws', 'route53', 'list-resource-record-sets', '--hosted-zone-id', HOSTED_ZONE_ID],
        capture_output=True, text=True
    )
    
    if result.returncode != 0:
        log_error(f"Failed to list Route53 records: {result.stderr}")
        return False
    
    try:
        data = json.loads(result.stdout)
        records = data.get('ResourceRecordSets', [])
        
        # Check if record already exists for update
        existing = [r for r in records if r.get('Name') == f"{DOMAIN_NAME}."]
        if existing:
            record = existing[0]
            record_type = record.get('Type')
            current_value = record.get('ResourceRecords', [{}])[0].get('Value', '')
            
            if record_type == 'CNAME' and current_value == CLOUDFRONT_DOMAIN:
                log_info(f"Record already correct: {DOMAIN_NAME} -> {CLOUDFRONT_DOMAIN}")
                return True
            
            # Need to update: first delete the old record
            log_info(f"Updating existing {record_type} record from {current_value}")
            
            delete_batch = {
                'Changes': [
                    {
                        'Action': 'DELETE',
                        'ResourceRecordSet': record
                    }
                ]
            }
            
            delete_result = subprocess.run(
                ['aws', 'route53', 'change-resource-record-sets',
                 '--hosted-zone-id', HOSTED_ZONE_ID,
                 '--change-batch', json.dumps(delete_batch)],
                capture_output=True, text=True
            )
            
            if delete_result.returncode != 0:
                log_error(f"Failed to delete old record: {delete_result.stderr}")
                return False

    except json.JSONDecodeError as e:
        log_error(f"Failed to parse Route53 response: {e}")
        return False
    
    # Create the Route53 CNAME record
    change_batch = {
        'Changes': [
            {
                'Action': 'CREATE',
                'ResourceRecordSet': {
                    'Name': DOMAIN_NAME,
                    'Type': 'CNAME',
                    'TTL': 300,
                    'ResourceRecords': [
                        {'Value': CLOUDFRONT_DOMAIN}
                    ]
                }
            }
        ]
    }
    
    log_info(f"Creating CNAME: {DOMAIN_NAME} -> {CLOUDFRONT_DOMAIN}")
    
    result = subprocess.run(
        ['aws', 'route53', 'change-resource-record-sets',
         '--hosted-zone-id', HOSTED_ZONE_ID,
         '--change-batch', json.dumps(change_batch)],
        capture_output=True, text=True
    )
    
    if result.returncode == 0:
        log_info("Route53 record created successfully! ✅")
        log_info(f"  Domain: {DOMAIN_NAME}")
        log_info(f"  Type: CNAME")
        log_info(f"  Target: {CLOUDFRONT_DOMAIN}")
        log_info(f"  TTL: 300 seconds")
        log_info("")
        log_info("⏳ DNS propagation may take a few minutes...")
        return True
    else:
        # Check if it's a "resource already exists" error
        if "InvalidChangeBatch" in result.stderr and "already exists" in result.stderr:
            log_info("Route53 record already exists ✅")
            return True
        
        log_error(f"Failed to create Route53 record: {result.stderr}")
        return False

if __name__ == '__main__':
    if not create_route53_record():
        sys.exit(1)
