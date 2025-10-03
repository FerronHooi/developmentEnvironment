"""
Simple rate limit helper for API extraction
"""

import time


def rate_limit(max_requests_per_minute: int, last_request_time: float = 0) -> float:
    """
    Simple rate limiter - waits if necessary to not exceed API limits

    Args:
        max_requests_per_minute: Maximum requests allowed per minute
        last_request_time: Timestamp of last request (0 for first request)

    Returns:
        Current timestamp after waiting

    Usage:
        last_time = 0
        for item in items:
            last_time = rate_limit(90, last_time)  # 90 requests per minute
            make_api_call()
    """
    min_interval = 60.0 / max_requests_per_minute
    elapsed = time.time() - last_request_time

    if elapsed < min_interval:
        time.sleep(min_interval - elapsed)

    return time.time()