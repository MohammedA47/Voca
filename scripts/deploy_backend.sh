#!/bin/bash

# Deployment Script for Oxford Pronunciation Backend

echo "=========================================="
echo "  Oxford Pronunciation Backend Deployment"
echo "=========================================="

# Check if supabase CLI is installed
if ! command -v supabase &> /dev/null; then
  echo "Error: 'supabase' CLI is not found."
  echo "Please install it first:"
  echo "  Brew: brew install supabase/tap/supabase"
  echo "  NPM: npm install -g supabase"
  exit 1
fi

echo "Please ensure you have created a new Supabase project at https://supabase.com/dashboard"
echo "You will need your Project Reference ID (e.g., 'abcdefghijklm')"
read -p "Enter your Project Reference ID: " PROJECT_ID

if [ -z "$PROJECT_ID" ]; then
  echo "Project ID cannot be empty."
  exit 1
fi

echo ""
echo "Step 1: Logging in to Supabase CLI..."
supabase login

echo ""
echo "Step 2: Linking Project..."
supabase link --project-ref "$PROJECT_ID"

echo ""
echo "Step 3: Pushing Database Schema..."
supabase db push

echo ""
echo "Step 4: Deploying Edge Functions..."
supabase functions deploy --no-verify-jwt

echo ""
echo "=========================================="
echo "  Deployment Complete!"
echo "=========================================="
echo "Next Steps:"
echo "1. Go to your Supabase Dashboard."
echo "2. Add your ElevenLabs API Key as a secret:"
echo "   supabase secrets set ELEVEN_LABS_API_KEY=your_key_here"
echo "3. Update your frontend .env file with the new Supabase URL and Anon Key."
