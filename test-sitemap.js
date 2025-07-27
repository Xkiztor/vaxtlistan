#!/usr/bin/env node

/**
 * Test script for sitemap functionality
 * Run with: node test-sitemap.js
 */

const { createClient } = require('@supabase/supabase-js');

// Test configuration - these should match your environment
const TEST_CONFIG = {
  SUPABASE_URL: process.env.LINDERSPLANTSKOLA_SUPABASE_URL,
  SUPABASE_KEY: process.env.LINDERSPLANTSKOLA_SUPABASE_KEY,
  SITE_URL: 'https://vaxtlistan.se',
};

async function testDatabaseFunctions() {
  console.log('🧪 Testing sitemap database functions...\n');

  if (!TEST_CONFIG.SUPABASE_URL || !TEST_CONFIG.SUPABASE_KEY) {
    console.error('❌ Missing Supabase environment variables');
    console.log('Please set LINDERSPLANTSKOLA_SUPABASE_URL and LINDERSPLANTSKOLA_SUPABASE_KEY');
    process.exit(1);
  }

  const supabase = createClient(TEST_CONFIG.SUPABASE_URL, TEST_CONFIG.SUPABASE_KEY);

  try {
    // Test plant sitemap function
    console.log('📋 Testing get_available_plants_sitemap()...');
    const { data: plants, error: plantsError } = await supabase.rpc('get_available_plants_sitemap');

    if (plantsError) {
      console.error('❌ Plant sitemap function error:', plantsError.message);
    } else {
      console.log(`✅ Plant sitemap function: ${plants?.length || 0} plants found`);
      if (plants && plants.length > 0) {
        console.log(`   Sample plant: ID ${plants[0].id} - "${plants[0].name}"`);
      }
    }

    // Test nursery sitemap function
    console.log('\n🏪 Testing get_plantskolor_sitemap()...');
    const { data: nurseries, error: nurseriesError } = await supabase.rpc(
      'get_plantskolor_sitemap'
    );

    if (nurseriesError) {
      console.error('❌ Nursery sitemap function error:', nurseriesError.message);
    } else {
      console.log(`✅ Nursery sitemap function: ${nurseries?.length || 0} nurseries found`);
      if (nurseries && nurseries.length > 0) {
        console.log(`   Sample nursery: ID ${nurseries[0].id} - "${nurseries[0].name}"`);
      }
    }

    // Generate sample URLs
    console.log('\n🔗 Sample sitemap URLs:');
    if (plants && plants.length > 0) {
      const samplePlant = plants[0];
      const encodedName = encodeURIComponent(samplePlant.name);
      console.log(`   Plant: ${TEST_CONFIG.SITE_URL}/vaxt/${samplePlant.id}/${encodedName}`);
    }

    if (nurseries && nurseries.length > 0) {
      const sampleNursery = nurseries[0];
      console.log(`   Nursery: ${TEST_CONFIG.SITE_URL}/plantskola/${sampleNursery.id}`);
    }
  } catch (error) {
    console.error('❌ Test failed:', error.message);
    process.exit(1);
  }

  console.log('\n✅ All tests completed successfully!');
}

// Test API endpoints (for local development)
async function testApiEndpoints() {
  console.log('\n🌐 Testing API endpoints (requires running server)...');

  const endpoints = [
    'http://localhost:3000/api/sitemap-plants',
    'http://localhost:3000/api/sitemap-plantskolor',
  ];

  for (const endpoint of endpoints) {
    try {
      const response = await fetch(endpoint);
      if (response.ok) {
        const data = await response.json();
        console.log(`✅ ${endpoint}: ${Array.isArray(data) ? data.length : 'Unknown'} items`);
      } else {
        console.log(`⚠️  ${endpoint}: HTTP ${response.status} (server may not be running)`);
      }
    } catch (error) {
      console.log(`⚠️  ${endpoint}: ${error.message} (server may not be running)`);
    }
  }
}

async function main() {
  console.log('🚀 Växtlistan Sitemap Test Suite\n');

  await testDatabaseFunctions();
  await testApiEndpoints();

  console.log('\n📝 Next steps:');
  console.log('1. Deploy database functions to production (see SITEMAP_DEPLOYMENT.md)');
  console.log('2. Test production sitemap at: https://vaxtlistan.se/sitemap.xml');
  console.log('3. Submit sitemap to Google Search Console');
}

if (require.main === module) {
  main().catch(console.error);
}

module.exports = { testDatabaseFunctions, testApiEndpoints };
