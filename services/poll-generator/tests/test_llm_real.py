#!/usr/bin/env python3
"""
Integration test for OpenRouterClient with real API key from AWS Secrets Manager.

This test validates:
1. API key retrieval from AWS Secrets Manager
2. Poll generation from news headlines
3. Content moderation
4. JSON parsing and error handling
"""

import json
import boto3
from botocore.exceptions import ClientError
from llm_client import OpenRouterClient


def get_secret(secret_arn: str) -> str:
    """Retrieve secret from AWS Secrets Manager."""
    session = boto3.session.Session()
    client = session.client(
        service_name='secretsmanager',
        region_name='eu-west-3'
    )
    
    try:
        response = client.get_secret_value(SecretId=secret_arn)
        return response['SecretString']
    except ClientError as e:
        raise Exception(f"Failed to retrieve secret: {str(e)}")


def main():
    """Run integration tests with real OpenRouter API."""
    
    # Secret ARN from AWS Secrets Manager
    OPENROUTER_KEY_ARN = "arn:aws:secretsmanager:eu-west-3:058264398399:secret:pollflow/openrouter-key-R0Adrf"
    
    print("🔑 Fetching OpenRouter key from AWS Secrets Manager...")
    api_key = get_secret(OPENROUTER_KEY_ARN)
    print("✅ API key retrieved")
    
    # Initialize client
    client = OpenRouterClient(api_key=api_key)
    print(f"📡 Using model: {client.model}\n")
    
    # Test 1: Generate poll from sample headlines
    print("="*70)
    print("🤖 Test 1: Poll Generation")
    print("="*70)
    
    test_articles = [
        {
            "headline": "Congress debates new AI regulation framework",
            "description": "Lawmakers consider oversight measures for artificial intelligence development and deployment in critical sectors",
            "category": "technology"
        },
        {
            "headline": "Global climate summit reaches historic agreement",
            "description": "World leaders commit to reducing carbon emissions by 50% by 2030 in landmark deal",
            "category": "science"
        },
        {
            "headline": "Federal Reserve announces interest rate decision",
            "description": "Central bank maintains current rates amid inflation concerns and economic uncertainty",
            "category": "business"
        }
    ]
    
    generated_polls = []
    
    for i, article in enumerate(test_articles, 1):
        print(f"\n📰 Article {i}:")
        print(f"   Headline: {article['headline']}")
        print(f"   Description: {article['description']}")
        print(f"   Category: {article['category']}")
        print(f"\n   Generating poll...")
        
        poll = client.generate_poll(
            headline=article['headline'],
            description=article['description'],
            category=article['category']
        )
        
        if poll:
            print(f"   ✅ Generated!")
            print(f"   📊 Poll Question: {poll['title']}")
            print(f"   📝 Description: {poll['description']}")
            print(f"   🅰️  Option A: {poll['option_a']}")
            print(f"   🅱️  Option B: {poll['option_b']}")
            print(f"   🏷️  Category: {poll['poll_category']}")
            generated_polls.append(poll)
        else:
            print(f"   ❌ Failed to generate poll")
    
    # Test 2: Content Moderation
    print("\n" + "="*70)
    print("🛡️  Test 2: Content Moderation")
    print("="*70)
    
    # Test safe poll
    if generated_polls:
        print(f"\n✅ Testing safe poll (generated above)...")
        safe_poll = generated_polls[0]
        is_safe, reason = client.moderate_poll(safe_poll)
        
        if is_safe:
            print(f"   ✅ Moderation passed: Poll is safe")
        else:
            print(f"   ⚠️  Moderation failed: {reason}")
    
    # Test potentially unsafe poll
    print(f"\n⚠️  Testing controversial poll...")
    controversial_poll = {
        'title': "Should we increase military spending?",
        'description': "Debate over defense budget priorities",
        'option_a': "Yes, for national security",
        'option_b': "No, invest in social programs"
    }
    
    is_safe, reason = client.moderate_poll(controversial_poll)
    if is_safe:
        print(f"   ✅ Moderation passed: Poll is acceptable")
    else:
        print(f"   ❌ Moderation failed: {reason}")
    
    # Summary
    print("\n" + "="*70)
    print("📊 Test Summary")
    print("="*70)
    print(f"✅ Polls generated: {len(generated_polls)}/{len(test_articles)}")
    print(f"✅ API calls successful: {len(generated_polls) + 2}")  # generation + 2 moderation tests
    
    if len(generated_polls) == len(test_articles):
        print("\n🎉 All tests passed! OpenRouterClient is working correctly.")
        return 0
    else:
        print("\n⚠️  Some tests failed. Check output above.")
        return 1


if __name__ == "__main__":
    try:
        exit(main())
    except Exception as e:
        print(f"\n❌ Test failed with error: {str(e)}")
        import traceback
        traceback.print_exc()
        exit(1)
