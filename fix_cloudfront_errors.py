#!/usr/bin/env python3
"""
Fix CloudFront 404 errors by adding custom error response for SPA routing
"""

import json
import subprocess
import sys

def log_info(msg):
    print(f"[INFO] {msg}")

def log_error(msg):
    print(f"[ERROR] {msg}")

def fix_cloudfront_errors():
    DISTRIBUTION_ID = "E2N031064FD3ZI"
    
    log_info("Fixing CloudFront error responses for SPA...")
    
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
    
    # Check and add custom error responses
    error_responses = config.get('CustomErrorResponses', {}).get('Items', [])
    
    # Check if 404 error response already exists
    has_404_error = any(r.get('ErrorCode') == 404 for r in error_responses)
    
    if not has_404_error:
        log_info("Adding custom 404 error response")
        error_responses.append({
            'ErrorCode': 404,
            'ResponsePagePath': '/index.html',
            'ResponseCode': '200',
            'ErrorCachingMinTTL': 300
        })
        config['CustomErrorResponses']['Items'] = error_responses
        config['CustomErrorResponses']['Quantity'] = len(error_responses)
    else:
        log_info("404 error response already configured")
    
    # Write updated config to temp file
    with open('/tmp/cf-error-config.json', 'w') as f:
        json.dump(config, f)
    
    # Update distribution
    log_info("Updating CloudFront with error responses...") 
    update_result = subprocess.run([
        'aws', 'cloudfront', 'update-distribution',
        '--id', DISTRIBUTION_ID,
        '--distribution-config', 'file:///tmp/cf-error-config.json',
        '--if-match', etag
    ], capture_output=True, text=True)
    
    if update_result.returncode == 0:
        log_info("CloudFront error responses configured successfully! ✅")
        log_info("  404 errors will now serve index.html")
        log_info("  This allows React SPA routing to work correctly")
        return True
    else:
        log_error(f"Failed to update distribution: {update_result.stderr}")
        return False

if __name__ == '__main__':
    if not fix_cloudfront_errors():
        sys.exit(1)
