"""
Cost Optimization Dashboard - Collector Lambda

Reads cost and rightsizing data from AWS Cost Explorer and AWS Compute
Optimizer, and writes a single simplified JSON report to S3 for the
static dashboard frontend to consume.

This function is strictly read-only against AWS billing/compute APIs.
The only write it performs is uploading its own report file to S3.
"""

import json
import os
import boto3
from datetime import date, timedelta

DASHBOARD_BUCKET = os.environ["DASHBOARD_BUCKET"]
REPORT_KEY = os.environ.get("REPORT_KEY", "data/latest.json")

# Cost Explorer and Compute Optimizer are only available in us-east-1.
ce_client = boto3.client("ce", region_name="us-east-1")
co_client = boto3.client("compute-optimizer", region_name="us-east-1")
s3_client = boto3.client("s3")


def get_cost_by_service(days=30):
    """Daily cost grouped by AWS service for the last N days."""
    end = date.today()
    start = end - timedelta(days=days)

    response = ce_client.get_cost_and_usage(
        TimePeriod={"Start": start.isoformat(), "End": end.isoformat()},
        Granularity="DAILY",
        Metrics=["UnblendedCost"],
        GroupBy=[{"Type": "DIMENSION", "Key": "SERVICE"}],
    )

    daily_totals = []
    service_totals = {}

    for result in response.get("ResultsByTime", []):
        day_total = 0.0
        for group in result.get("Groups", []):
            service_name = group["Keys"][0]
            amount = float(group["Metrics"]["UnblendedCost"]["Amount"])
            day_total += amount
            service_totals[service_name] = service_totals.get(service_name, 0.0) + amount

        daily_totals.append({
            "date": result["TimePeriod"]["Start"],
            "amount": round(day_total, 4),
        })

    top_services = sorted(
        ({"service": k, "amount": round(v, 4)} for k, v in service_totals.items()),
        key=lambda x: x["amount"],
        reverse=True,
    )[:10]

    return {"daily_totals": daily_totals, "top_services": top_services}


def get_cost_forecast():
    """Forecasted spend for the current month to date + remaining days."""
    today = date.today()
    end_of_month = (today.replace(day=28) + timedelta(days=4)).replace(day=1) - timedelta(days=1)

    if today >= end_of_month:
        return {"forecasted_amount": 0.0, "period_start": None, "period_end": None}

    try:
        response = ce_client.get_cost_forecast(
            TimePeriod={
                "Start": (today + timedelta(days=1)).isoformat(),
                "End": end_of_month.isoformat(),
            },
            Metric="UNBLENDED_COST",
            Granularity="MONTHLY",
        )
        return {
            "forecasted_amount": round(float(response["Total"]["Amount"]), 2),
            "period_start": (today + timedelta(days=1)).isoformat(),
            "period_end": end_of_month.isoformat(),
        }
    except ce_client.exceptions.ClientError:
        # Cost Explorer forecast requires enough historical data; a new
        # account or a very short billing history can raise an error here.
        return {"forecasted_amount": None, "period_start": None, "period_end": None}


def get_rightsizing_recommendations():
    """EC2 rightsizing recommendations from Cost Explorer."""
    try:
        response = ce_client.get_rightsizing_recommendation(
            Service="AmazonEC2",
            Configuration={"RecommendationTarget": "SAME_INSTANCE_FAMILY", "BenefitsConsidered": True},
        )
    except ce_client.exceptions.ClientError:
        return []

    recommendations = []
    for rec in response.get("RightsizingRecommendations", []):
        current = rec.get("CurrentInstance", {})
        modify_details = rec.get("ModifyRecommendationDetail", {})
        target_instances = modify_details.get("TargetInstances", [])
        target = target_instances[0] if target_instances else {}

        recommendations.append({
            "instance_id": current.get("ResourceId", "unknown"),
            "current_type": current.get("InstanceType", "unknown"),
            "recommended_type": target.get("ResourceDetails", {})
                .get("EC2ResourceDetails", {}).get("InstanceType", "unknown"),
            "estimated_monthly_savings": round(
                float(target.get("EstimatedMonthlySavings", 0) or 0), 2
            ),
            "finding": rec.get("RightsizingType", "unknown"),
        })

    return recommendations


def get_ec2_graviton_candidates():
    """EC2 instances Compute Optimizer flags as over-provisioned or migratable."""
    try:
        response = co_client.get_ec2_instance_recommendations()
    except co_client.exceptions.ClientError:
        return []

    candidates = []
    for rec in response.get("instanceRecommendations", []):
        options = rec.get("recommendationOptions", [])
        best_option = options[0] if options else {}

        candidates.append({
            "instance_arn": rec.get("instanceArn", "unknown"),
            "current_type": rec.get("currentInstanceType", "unknown"),
            "recommended_type": best_option.get("instanceType", "unknown"),
            "finding": rec.get("finding", "unknown"),
            "estimated_monthly_savings": round(
                float(
                    best_option.get("savingsOpportunity", {})
                    .get("estimatedMonthlySavings", {})
                    .get("value", 0) or 0
                ),
                2,
            ),
        })

    return candidates


def get_idle_lambda_functions():
    """Lambda functions Compute Optimizer flags as over-provisioned/idle."""
    try:
        response = co_client.get_lambda_function_recommendations()
    except co_client.exceptions.ClientError:
        return []

    idle_functions = []
    for rec in response.get("lambdaFunctionRecommendations", []):
        idle_functions.append({
            "function_arn": rec.get("functionArn", "unknown"),
            "current_memory_mb": rec.get("currentMemorySize", 0),
            "finding": rec.get("finding", "unknown"),
        })

    return idle_functions


def get_compute_optimizer_enrollment():
    """Whether Compute Optimizer is opted in for this account."""
    try:
        response = co_client.get_enrollment_status()
        return response.get("status", "Unknown")
    except co_client.exceptions.ClientError:
        return "Unknown"


def handler(event, context):
    report = {
        "generated_at": date.today().isoformat(),
        "cost": get_cost_by_service(days=30),
        "forecast": get_cost_forecast(),
        "compute_optimizer_enrollment": get_compute_optimizer_enrollment(),
        "rightsizing_recommendations": get_rightsizing_recommendations(),
        "graviton_candidates": get_ec2_graviton_candidates(),
        "idle_lambda_functions": get_idle_lambda_functions(),
    }

    s3_client.put_object(
        Bucket=DASHBOARD_BUCKET,
        Key=REPORT_KEY,
        Body=json.dumps(report, indent=2),
        ContentType="application/json",
        CacheControl="max-age=300",
    )

    return {
        "statusCode": 200,
        "body": json.dumps({"message": "Report generated successfully", "key": REPORT_KEY}),
    }