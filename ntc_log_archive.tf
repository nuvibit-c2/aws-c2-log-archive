# =====================================================================================================================
# NTC LOG ARCHIVE - CENTRALIZED AUDIT LOG STORAGE
# =====================================================================================================================
# Secure, compliant, and cost-optimized storage for organization-wide audit logs
#
# WHAT IS LOG ARCHIVE?
# --------------------
# A dedicated AWS account for storing audit-relevant logs in isolation from production workloads
# Provides tamper-proof, long-term retention of security and compliance logs
#
# WHY SEPARATE LOG ARCHIVE ACCOUNT?
# ----------------------------------
# Security Best Practice: Isolate audit logs from operational accounts
#   ✓ Prevent log tampering by limiting access to security/audit team only
#   ✓ Protect against malicious actors deleting evidence of unauthorized activity
#   ✓ Comply with audit requirements (SOC 2, ISO 27001, PCI-DSS, GDPR)
#   ✓ Enforce principle of least privilege - developers cannot access audit logs
#
# Compliance Requirements:
#   • Audit logs must be immutable and tamper-proof
#   • Logs must be retained for specific periods (1-7 years depending on framework)
#   • Access to audit logs must be restricted and logged
#   • Logs must be encrypted at rest and in transit
#
# ⚠️  CRITICAL: ACCESS CONTROL
# ---------------------------
# RESTRICT ACCESS TO THIS ACCOUNT TO SECURITY/AUDIT PERSONNEL ONLY!
# 
# Why this matters:
#   • Log Archive contains evidence of ALL activity across the organization
#   • Tampering with logs can hide security incidents, breaches, or policy violations
#   • Auditors require proof that logs cannot be altered by unauthorized personnel
#   • Compliance frameworks mandate strict access controls for audit logs
#
# Who should have access:
#   ✓ Security team (read-only for investigations)
#   ✓ Compliance/audit team (read-only for audits)
#   ✓ Infrastructure team (infrastructure changes only, not log access)
#
# Who should NOT have access:
#   ✗ Developers
#   ✗ Application teams
#   ✗ Business users
#   ✗ Third-party vendors (unless specifically required for audit)
#
# WHAT LOGS ARE STORED HERE?
# ---------------------------
# AUDIT LOGS (Security & Compliance):
#   ✓ CloudTrail: API activity across all accounts (who did what, when)
#   ✓ GuardDuty: Threat detection findings (malicious activity, anomalies)
#   ✓ VPC Flow Logs: Network traffic metadata (source, destination, protocol)
#   ✓ Transit Gateway Flow Logs: Inter-VPC and on-premises traffic
#   ✓ DNS Query Logs: DNS resolution requests (detect data exfiltration)
#   ✓ AWS Config: Resource configuration history (compliance tracking)
#
# WHAT SHOULD NOT BE STORED HERE?
# --------------------------------
#   ✗ Application logs (stdout/stderr from containers/EC2)
#   ✗ Application metrics (CloudWatch metrics, custom metrics)
#   ✗ Performance logs (APM traces, profiling data)
#   ✗ Business analytics data
#   ✗ Development/debug logs
#
# Store application logs in:
#   • Application account's CloudWatch Logs
#   • Centralized monitoring account
#   • Third-party logging services (Datadog, Splunk, etc.)
#
# Each bucket:
#   • KMS encryption (dedicated CMK per bucket)
#   • Versioning enabled
#   • Lifecycle policies (Glacier → Expiration)
#   • Bucket policies (least privilege per archive type)
#   • Optional: Object Lock (COMPLIANCE mode for immutability)
#
# COST OPTIMIZATION:
# ------------------
# Lifecycle Configuration Strategy:
#   1. S3 Standard (0-365 days): Frequent access for recent investigations
#   2. S3 Glacier (1-X years): Long-term compliance retention, infrequent access
#   3. Expiration (X years): Delete after compliance period ends
#
# Customize retention based on your compliance requirements
#
# SECURITY FEATURES:
# ------------------
# Automatic Security Controls:
#   ✓ KMS encryption at rest (dedicated CMK per bucket, automatic key rotation)
#   ✓ TLS encryption in transit (enforced via bucket policy)
#   ✓ Bucket policies (least privilege, archive-type specific)
#   ✓ Versioning enabled (protect against accidental deletion)
#   ✓ Public access blocked (organization-level enforcement)
#   ✓ Access logging (optional, audit bucket access)
#
# Object Lock (COMPLIANCE Mode):
#   • Immutable logs - cannot be deleted or modified before retention period
#   • Use for: Regulatory requirements, audit trail protection
#   • ⚠️  WARNING: Once enabled, objects CANNOT be deleted until retention expires
#   • ⚠️  Only way to delete: Close the entire AWS account
#   • Best Practice: Enable Object Lock AFTER initial testing is complete
#
# GUARDDUTY LIMITATION - OPT-IN REGIONS:
# ---------------------------------------
# ⚠️  GuardDuty export findings CANNOT be stored in opt-in regions (e.g., Zurich eu-central-2)
# AWS Limitation: GuardDuty only supports exporting to standard AWS regions
# Reference: https://docs.aws.amazon.com/guardduty/latest/ug/guardduty_exportfindings.html
#
# Solution: Split log archive across two regions:
#   • Main Region (eu-central-2): All logs except GuardDuty
#   • Secondary Region (eu-central-1): GuardDuty findings only
#
# Note: Cross-region access logging is not supported
# =====================================================================================================================

# =====================================================================================================================
# LOCALS - LIFECYCLE CONFIGURATION
# =====================================================================================================================
# Define default lifecycle rules for cost optimization
# Customize based on your compliance and regulatory requirements
# =====================================================================================================================
locals {
  # -------------------------------------------------------------------------------------------------------------------
  # Default Lifecycle Configuration Rules
  # -------------------------------------------------------------------------------------------------------------------
  # Optimize storage costs while meeting compliance retention requirements
  # 
  # Rule 1: Transition to Glacier after 1 year
  #   • Reduces storage costs by ~80% for infrequently accessed logs
  #   • Suitable for compliance archives requiring long-term retention
  #
  # Rule 2: Expire logs after 2 years
  #   • Automatically delete logs after compliance period ends
  #   • Adjust expiration_days based on your requirements:
  #     - 1095 days (3 years)
  #     - 2190 days (6 years)
  #     - 2555 days (7 years)
  #
  # Per-Bucket Customization:
  #   • You can override these rules for specific buckets below
  #   • Example: Keep CloudTrail for 7 years, VPC Flow Logs for 1 year
  # -------------------------------------------------------------------------------------------------------------------
  default_lifecycle_configuration_rules = [
    {
      id      = "transition_to_glacier"
      enabled = true
      transition = {
        days          = 365       # Move to Glacier after 1 year
        storage_class = "GLACIER" # Cold storage for compliance archives
      }
    },
    {
      id      = "expire_logs"
      enabled = true
      expiration = {
        days = 730 # Delete after 2 years (adjust per compliance)
      }
    }
  ]
}

# =====================================================================================================================
# S3 ACCESS LOGGING BUCKET - AUDIT BUCKET ACCESS
# =====================================================================================================================
# Records all access to log archive buckets for security auditing
# 
# WHY SEPARATE MODULE CALL?
# --------------------------
# Terraform Dependency Management:
#   • Access logging bucket must exist BEFORE other buckets can reference it
#   • Separate module call ensures proper creation order
#   • Avoids circular dependency issues
#
# WHAT IS S3 ACCESS LOGGING?
# ---------------------------
# Records every request made to your S3 buckets:
#   • Who accessed the bucket (IAM principal, role, federated user)
#   • When the access occurred (timestamp)
#   • What operation was performed (GetObject, PutObject, DeleteObject)
#   • Source IP address
#   • HTTP status code (success/failure)
#   • Error codes (if access was denied)
#
# USE CASES:
# ----------
#   • Detect unauthorized access attempts to audit logs
#   • Investigate suspicious activity (unusual access patterns)
#   • Compliance audits (prove who accessed logs and when)
#   • Forensic analysis after security incidents
#
# ⚠️  IMPORTANT: NEVER ENABLE ACCESS LOGGING ON THIS BUCKET ITSELF!
# -----------------------------------------------------------------
# Enabling access logging on the access logging bucket creates an infinite loop:
#   1. Access to main bucket → generates log in access logging bucket
#   2. Writing log to access logging bucket → generates another log
#   3. Writing that log → generates another log (infinite recursion)
# Result: Exponential log growth, high costs, potential S3 throttling
#
# SECURITY CONSIDERATIONS:
# ------------------------
#   • This bucket contains sensitive metadata about bucket access
#   • Access should be even more restricted than regular log archives
#   • Useful for detecting insider threats or compromised credentials
#   • Retention can be shorter than main logs (1 year is common)
# =====================================================================================================================
module "ntc_log_archive_access_logging" {
  source = "github.com/nuvibit-terraform-collection/terraform-aws-ntc-log-archive?ref=1.3.0"

  # -------------------------------------------------------------------------------------------------------------------
  # S3 Access Logging Bucket Configuration
  # -------------------------------------------------------------------------------------------------------------------
  # Stores access logs for all other log archive buckets
  # ⚠️  Must be created first (separate module call)
  # ⚠️  Do NOT enable access logging on this bucket (causes infinite loop)
  # -------------------------------------------------------------------------------------------------------------------
  log_archive_buckets = [
    {
      bucket_name                   = "aws-c2-access-logging" # Bucket for S3 access logs
      archive_type                  = "s3_access_logging"     # Type: S3 access logging
      lifecycle_configuration_rules = local.default_lifecycle_configuration_rules
      # ⚠️  Object lock is not supported for access log bucket
      # https://docs.aws.amazon.com/AmazonS3/latest/userguide/enable-server-access-logging.html 
      object_lock_enabled = false
    }
  ]

  providers = {
    aws = aws.euc1
  }
}

# =====================================================================================================================
# LOG ARCHIVE BUCKETS - AUDIT LOG STORAGE
# =====================================================================================================================
# Centralized storage for all audit-relevant logs across the organization
#
# AUTOMATIC SECURITY FEATURES:
# ----------------------------
# Each bucket is automatically configured with:
#   ✓ KMS Encryption: Dedicated Customer Managed Key (CMK) per bucket
#   ✓ Key Rotation: Automatic annual rotation of KMS keys
#   ✓ Bucket Policy: Least privilege access based on 'archive_type'
#   ✓ KMS Key Policy: Automatic grants for AWS services (CloudTrail, VPC Flow Logs, etc.)
#   ✓ Versioning: Enabled for accidental deletion protection
#   ✓ Public Access Block: All public access blocked
#   ✓ TLS Enforcement: Deny unencrypted (HTTP) requests
#
# You don't need to configure these manually - the module handles everything!
#
# ARCHIVE TYPES AND THEIR PURPOSE:
# ---------------------------------
# Each 'archive_type' automatically configures the appropriate bucket and KMS policies
# =====================================================================================================================
module "ntc_log_archive" {
  source = "github.com/nuvibit-terraform-collection/terraform-aws-ntc-log-archive?ref=1.3.0"

  log_archive_buckets = [
    # =================================================================================================================
    # CLOUDTRAIL ARCHIVE - API ACTIVITY LOGS
    # =================================================================================================================
    # WHAT: Records all API calls made across the entire AWS Organization
    # WHY CRITICAL: 
    #   • Primary audit trail for "who did what, when" across all accounts
    #   • Detects unauthorized access, privilege escalation, data exfiltration
    #   • Required for compliance (SOC 2, ISO 27001, PCI-DSS, GDPR)
    #   • Forensic evidence for security incidents
    #
    # WHAT'S LOGGED:
    #   • API calls (CreateUser, DeleteBucket, ModifySecurityGroup, etc.)
    #   • Identity information (user, role, account ID, source IP)
    #   • Timestamps and AWS regions
    #   • Request parameters and response elements
    #   • Success/failure status
    #
    # USE CASES:
    #   • Detect unauthorized account changes
    #   • Track privileged user activity
    #   • Identify security group modifications
    #   • Audit S3 bucket policy changes
    #   • Investigate suspicious API activity
    #
    # OBJECT LOCK RECOMMENDATION:
    #   • Enable for high-security environments
    #   • Required for: Financial services, healthcare, government
    #   • Provides tamper-proof audit trail
    #   • ⚠️  Test thoroughly before enabling (cannot be disabled)
    # =================================================================================================================
    {
      bucket_name                       = "aws-c2-cloudtrail-archive"
      archive_type                      = "org_cloudtrail" # CloudTrail organization trail
      lifecycle_configuration_rules     = local.default_lifecycle_configuration_rules
      enable_access_logging             = true # Track bucket access
      access_logging_target_bucket_name = module.ntc_log_archive_access_logging.log_archive_bucket_ids["s3_access_logging"]
      access_logging_target_prefix      = "org_cloudtrail/"

      # -----------------------------------------------------------------------------------------------------------------
      # Object Lock - Immutable Audit Trail (Optional but Recommended)
      # -----------------------------------------------------------------------------------------------------------------
      # ⚠️  CRITICAL: Enable Object Lock ONLY after thorough testing!
      # 
      # COMPLIANCE Mode:
      #   • Objects CANNOT be deleted or modified before retention period expires
      #   • Not even root user or account owner can delete
      #   • Only way to delete: Close the entire AWS account (or wait for expiration)
      #
      # When to Enable:
      #   ✓ Regulatory requirements mandate immutable logs
      #   ✓ High-security environments (financial, healthcare, government)
      #   ✓ Protection against insider threats
      #   ✓ After initial testing phase is complete
      #
      # When NOT to Enable:
      #   ✗ During development/testing (hard to clean up test data)
      #   ✗ If retention requirements are unclear
      #   ✗ If you need flexibility to delete old logs
      #
      # Best Practice:
      #   1. Deploy without Object Lock first
      #   2. Validate log delivery and lifecycle policies work correctly
      #   3. Test retention periods match your compliance needs
      #   4. Enable Object Lock in production after validation
      # -----------------------------------------------------------------------------------------------------------------
      #
      # object_lock_enabled = true
      # object_lock_configuration = {
      #   retention_mode = "COMPLIANCE"
      #   retention_days = 365
      # }
    },

    # =================================================================================================================
    # VPC FLOW LOGS ARCHIVE - NETWORK TRAFFIC METADATA
    # =================================================================================================================
    # WHAT: IP traffic metadata for all network interfaces in VPCs
    # WHY CRITICAL:
    #   • Detect unauthorized network access and lateral movement
    #   • Identify suspicious traffic patterns and data exfiltration
    #   • Troubleshoot network connectivity issues
    #   • Compliance requirement for network monitoring
    #
    # WHAT'S LOGGED:
    #   • Source and destination IP addresses
    #   • Source and destination ports
    #   • Protocol (TCP, UDP, ICMP)
    #   • Packet and byte counts
    #   • Action (ACCEPT or REJECT by security groups/NACLs)
    #   • Timestamps
    #
    # USE CASES:
    #   • Detect port scanning and brute force attacks
    #   • Identify unauthorized connections to databases
    #   • Track data transfer volumes (potential exfiltration)
    #   • Investigate security group misconfigurations
    #   • Analyze traffic patterns for optimization
    # =================================================================================================================
    {
      bucket_name                       = "aws-c2-vpc-flow-logs-archive"
      archive_type                      = "vpc_flow_logs" # VPC Flow Logs
      lifecycle_configuration_rules     = local.default_lifecycle_configuration_rules
      enable_access_logging             = true
      access_logging_target_bucket_name = module.ntc_log_archive_access_logging.log_archive_bucket_ids["s3_access_logging"]
      access_logging_target_prefix      = "vpc_flow_logs/"
    },

    # =================================================================================================================
    # TRANSIT GATEWAY FLOW LOGS ARCHIVE - INTER-VPC NETWORK TRAFFIC
    # =================================================================================================================
    # WHAT: IP traffic metadata crossing Transit Gateway attachments
    # WHY CRITICAL:
    #   • Monitor traffic between VPCs and on-premises networks
    #   • Detect unauthorized cross-account or cross-VPC communication
    #   • Track hybrid cloud connectivity
    #   • Compliance for network segmentation
    #
    # WHAT'S LOGGED:
    #   • Source and destination VPCs/attachments
    #   • IP addresses and ports
    #   • Protocol and packet counts
    #   • Action (routed or dropped)
    #
    # USE CASES:
    #   • Verify network segmentation policies
    #   • Detect unauthorized cross-environment traffic (prod → dev)
    #   • Monitor on-premises to cloud traffic
    #   • Troubleshoot Transit Gateway routing issues
    # =================================================================================================================
    {
      bucket_name                       = "aws-c2-transit-gateway-logs-archive"
      archive_type                      = "transit_gateway_flow_logs" # Transit Gateway Flow Logs
      lifecycle_configuration_rules     = local.default_lifecycle_configuration_rules
      enable_access_logging             = true
      access_logging_target_bucket_name = module.ntc_log_archive_access_logging.log_archive_bucket_ids["s3_access_logging"]
      access_logging_target_prefix      = "transit_gateway_flow_logs/"
    },

    # =================================================================================================================
    # DNS QUERY LOGS ARCHIVE - DNS RESOLUTION REQUESTS
    # =================================================================================================================
    # WHAT: All DNS queries made from VPCs (Route 53 Resolver Query Logs)
    # WHY CRITICAL:
    #   • Detect DNS tunneling and data exfiltration
    #   • Identify malware command & control (C2) communication
    #   • Track access to suspicious domains
    #   • Troubleshoot DNS resolution issues
    #
    # WHAT'S LOGGED:
    #   • Query domain name (example.com)
    #   • Query type (A, AAAA, MX, TXT, etc.)
    #   • Response code (NOERROR, NXDOMAIN, SERVFAIL)
    #   • Source IP address
    #   • Timestamps
    #
    # USE CASES:
    #   • Detect DNS tunneling for data exfiltration
    #   • Identify malware beaconing to C2 servers
    #   • Track access to known malicious domains
    #   • Monitor DNS queries to unusual TLDs (.tk, .xyz, etc.)
    #   • Investigate phishing or malware infections
    # =================================================================================================================
    {
      bucket_name                       = "aws-c2-dns-query-logs-archive"
      archive_type                      = "dns_query_logs" # Route 53 Resolver Query Logs
      lifecycle_configuration_rules     = local.default_lifecycle_configuration_rules
      enable_access_logging             = true
      access_logging_target_bucket_name = module.ntc_log_archive_access_logging.log_archive_bucket_ids["s3_access_logging"]
      access_logging_target_prefix      = "dns_query_logs/"
    },

    # =================================================================================================================
    # GUARDDUTY ARCHIVE - THREAT DETECTION FINDINGS
    # =================================================================================================================
    # WHAT: Security findings from AWS GuardDuty threat detection service
    # WHY CRITICAL:
    #   • Automated threat detection using machine learning
    #   • Identifies malicious activity and unauthorized behavior
    #   • Detects compromised instances, accounts, and data
    #   • Real-time security monitoring across all accounts
    #
    # WHAT'S LOGGED:
    #   • Threat findings (malware, crypto mining, data exfiltration)
    #   • Severity levels (LOW, MEDIUM, HIGH, CRITICAL)
    #   • Affected resources (EC2, IAM, S3, etc.)
    #   • Threat indicators (IPs, domains, user agents)
    #   • Recommended remediation actions
    #
    # USE CASES:
    #   • Detect compromised EC2 instances (crypto mining, botnets)
    #   • Identify stolen credentials or IAM access keys
    #   • Monitor for S3 bucket data exfiltration
    #   • Alert on reconnaissance and port scanning
    #   • Track privilege escalation attempts
    #
    # ⚠️  GUARDDUTY LIMITATION - OPT-IN REGIONS:
    # -----------------------------------------
    # GuardDuty CANNOT export findings to opt-in regions (e.g., Zurich eu-central-2)
    # AWS Limitation: https://docs.aws.amazon.com/guardduty/latest/ug/guardduty_exportfindings.html
    #
    # If your main region is an opt-in region:
    #   • Split log archive across TWO regions
    #   • Main region: All logs EXCEPT GuardDuty
    #   • Secondary region: GuardDuty findings only (see example below)
    #   • Note: Cross-region access logging is not supported
    # =================================================================================================================
    {
      bucket_name                       = "aws-c2-guardduty-archive"
      archive_type                      = "guardduty" # GuardDuty findings
      lifecycle_configuration_rules     = local.default_lifecycle_configuration_rules
      enable_access_logging             = true
      access_logging_target_bucket_name = module.ntc_log_archive_access_logging.log_archive_bucket_ids["s3_access_logging"]
      access_logging_target_prefix      = "guardduty/"
    },

    # =================================================================================================================
    # AWS CONFIG ARCHIVE - RESOURCE CONFIGURATION HISTORY
    # =================================================================================================================
    # WHAT: Historical record of AWS resource configurations and changes
    # WHY CRITICAL:
    #   • Track configuration changes over time
    #   • Compliance auditing (prove configuration at specific dates)
    #   • Detect configuration drift and unauthorized changes
    #   • Relationship mapping between resources
    #
    # WHAT'S LOGGED:
    #   • Resource configuration snapshots (JSON format)
    #   • Configuration change history
    #   • Resource relationships and dependencies
    #   • Compliance status against AWS Config Rules
    #   • Resource creation and deletion timestamps
    #
    # USE CASES:
    #   • Prove compliance at a specific point in time
    #   • Track security group rule changes
    #   • Monitor IAM policy modifications
    #   • Detect encryption setting changes
    #   • Troubleshoot "what changed" for broken resources
    #   • Audit trail for compliance frameworks (PCI-DSS, HIPAA)
    #
    # IAM ROLE CONFIGURATION:
    #   • config_iam_role_name: IAM role for AWS Config service
    #   • Automatically granted S3 and KMS permissions by module
    #   • ⚠️  IMPORTANT: Use the SAME role name when deploying AWS Config to workload accounts
    #   • This role name must match in Account Baseline templates for cross-account Config delivery
    #   • Example: Account Factory baseline template for AWS Config should reference this role name
    # =================================================================================================================
    {
      bucket_name                       = "aws-c2-config-archive"
      archive_type                      = "aws_config" # AWS Config snapshots
      lifecycle_configuration_rules     = local.default_lifecycle_configuration_rules
      config_iam_path                   = "/"               # IAM path for Config role
      config_iam_role_name              = "ntc-config-role" # ⚠️  Must match role name in workload accounts
      enable_access_logging             = true
      access_logging_target_bucket_name = module.ntc_log_archive_access_logging.log_archive_bucket_ids["s3_access_logging"]
      access_logging_target_prefix      = "aws_config/"
    }
  ]

  providers = {
    aws = aws.euc1 # Main region for log archive
  }
}

# =====================================================================================================================
# LOG ARCHIVE EXCEPTION - OPT-IN REGION WORKAROUND
# =====================================================================================================================
# Use this module when your main region is an OPT-IN region (e.g., Zurich eu-central-2)
#
# GUARDDUTY OPT-IN REGION LIMITATION:
# ------------------------------------
# AWS GuardDuty CANNOT export findings to opt-in regions
# Supported regions: https://docs.aws.amazon.com/guardduty/latest/ug/guardduty_exportfindings.html
#
# PROBLEM:
# --------
# If your log archive runs in Zurich (eu-central-2):
#   ✗ GuardDuty in Frankfurt (eu-central-1) cannot export to Zurich
#   ✗ All opt-in regions have this limitation
#
# SOLUTION:
# ---------
# Split log archive across TWO regions:
#   Region 1 (Opt-in): All logs EXCEPT GuardDuty (see module above)
#   Region 2 (Standard): GuardDuty findings ONLY (this module)
#
# CONFIGURATION NOTES:
# --------------------
# • enable_access_logging = false (cross-region access logging not supported or create additional access log bucket)
# • Use a standard AWS region provider (e.g., aws.use1 for eu-central-1)
# • Bucket name should indicate the exception (e.g., include region in name)
# • Lifecycle rules same as main archive for consistency
#
# WHEN TO USE THIS:
# -----------------
# ✓ Main log archive in opt-in region (Zurich, Milan, Spain, etc.)
# ✓ Need GuardDuty findings storage
# ✗ Don't use if main region is already a standard region
#
# EXAMPLE SCENARIO:
# -----------------
# Main Archive (Zurich eu-central-2):
#   • CloudTrail, VPC Flow Logs, DNS Query Logs, AWS Config, etc.
#
# Exception Archive (Frankfurt eu-central-1):
#   • GuardDuty findings ONLY
# =====================================================================================================================

# Uncomment this module if your main region is an opt-in region
# module "ntc_log_archive_exception" {
#   source = "github.com/nuvibit-terraform-collection/terraform-aws-ntc-log-archive?ref=1.3.0"
#
#   # -----------------------------------------------------------------------------------------------------------------
#   # GuardDuty Archive in Standard Region
#   # -----------------------------------------------------------------------------------------------------------------
#   # Store GuardDuty findings in a standard AWS region (not opt-in)
#   # -----------------------------------------------------------------------------------------------------------------
#   log_archive_buckets = [
#     {
#       bucket_name                   = "aws-c2-guardduty-archive-euc1"  # Include region in name for clarity
#       archive_type                  = "guardduty"                      # GuardDuty findings only
#       lifecycle_configuration_rules = local.default_lifecycle_configuration_rules
#       enable_access_logging         = false                            # Cross-region access logging not supported
#       object_lock_enabled           = false                            # Typically not needed for exception bucket
#     }
#   ]
#
#   providers = {
#     aws = aws.use1                                                     # Use standard region provider (e.g., eu-central-1)
#   }
# }
