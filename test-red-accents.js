#!/usr/bin/env node

/**
 * PiSignage Red Accents Verification Test
 * 
 * This script tests whether the FREE.FR red accents (#DC2626) are properly
 * implemented throughout the interface by taking a screenshot and analyzing
 * the console for errors.
 */

const puppeteer = require('puppeteer');
const fs = require('fs');

async function testRedAccents() {
  console.log('🔴 Testing FREE.FR Red Accents Implementation...\n');
  
  const browser = await puppeteer.launch({
    headless: false,
    args: ['--no-sandbox', '--disable-setuid-sandbox'],
    defaultViewport: { width: 1920, height: 1080 }
  });

  try {
    const page = await browser.newPage();
    
    // Capture console errors
    const consoleErrors = [];
    page.on('console', msg => {
      if (msg.type() === 'error') {
        consoleErrors.push(msg.text());
      }
    });

    // Navigate to the application
    console.log('📱 Navigating to PiSignage application...');
    await page.goto('http://localhost:3000', { 
      waitUntil: 'networkidle2',
      timeout: 30000 
    });

    // Wait for the page to load completely
    await page.waitForTimeout(3000);

    // Take a screenshot for visual verification
    console.log('📸 Taking screenshot for visual verification...');
    await page.screenshot({ 
      path: '/opt/pisignage/red-accents-test.png',
      fullPage: true 
    });

    // Test 1: Check if red accent variables are defined
    console.log('✅ Test 1: Checking CSS red accent variables...');
    const redAccentVars = await page.evaluate(() => {
      const style = getComputedStyle(document.documentElement);
      return {
        accent: style.getPropertyValue('--ps-accent').trim(),
        accentHover: style.getPropertyValue('--ps-accent-hover').trim(),
        border: style.getPropertyValue('--ps-border').trim()
      };
    });
    
    if (redAccentVars.accent === '#DC2626' || redAccentVars.accent === 'rgb(220, 38, 38)') {
      console.log('   ✅ CSS variables correctly defined');
      console.log(`   --ps-accent: ${redAccentVars.accent}`);
    } else {
      console.log('   ❌ CSS accent variable not properly set');
      console.log(`   Found: ${redAccentVars.accent}, Expected: #DC2626`);
    }

    // Test 2: Count elements with red borders
    console.log('\n✅ Test 2: Counting elements with red borders...');
    const redBorderElements = await page.evaluate(() => {
      const elements = document.querySelectorAll('*');
      let count = 0;
      
      elements.forEach(el => {
        const style = getComputedStyle(el);
        const borderColor = style.borderColor;
        
        // Check for red border variations
        if (borderColor.includes('220, 38, 38') || 
            borderColor.includes('rgb(220, 38, 38)') ||
            borderColor.includes('#DC2626') ||
            borderColor.includes('red-600')) {
          count++;
        }
      });
      
      return count;
    });
    
    console.log(`   Found ${redBorderElements} elements with red borders`);
    if (redBorderElements >= 5) {
      console.log('   ✅ Sufficient red border elements detected');
    } else {
      console.log('   ⚠️  Low number of red border elements');
    }

    // Test 3: Check for red accent buttons
    console.log('\n✅ Test 3: Checking for red accent buttons...');
    const redButtons = await page.evaluate(() => {
      const buttons = document.querySelectorAll('button, .ps-btn-primary, .btn-premium');
      let count = 0;
      
      buttons.forEach(btn => {
        const style = getComputedStyle(btn);
        const bgColor = style.backgroundColor;
        
        if (bgColor.includes('220, 38, 38') || 
            bgColor.includes('rgb(220, 38, 38)') ||
            bgColor === 'rgb(220, 38, 38)') {
          count++;
        }
      });
      
      return count;
    });
    
    console.log(`   Found ${redButtons} red accent buttons`);
    if (redButtons >= 3) {
      console.log('   ✅ Red accent buttons properly implemented');
    } else {
      console.log('   ⚠️  Few red accent buttons found');
    }

    // Test 4: Check background color
    console.log('\n✅ Test 4: Verifying black background...');
    const backgroundColor = await page.evaluate(() => {
      return getComputedStyle(document.body).backgroundColor;
    });
    
    if (backgroundColor === 'rgb(0, 0, 0)' || backgroundColor === '#000000') {
      console.log('   ✅ Black background properly set');
    } else {
      console.log(`   ❌ Background not black: ${backgroundColor}`);
    }

    // Test 5: Console errors check
    console.log('\n✅ Test 5: Console errors analysis...');
    if (consoleErrors.length === 0) {
      console.log('   ✅ No console errors detected');
    } else {
      console.log(`   ⚠️  Found ${consoleErrors.length} console errors:`);
      consoleErrors.forEach(error => {
        console.log(`     - ${error}`);
      });
    }

    // Final Score
    console.log('\n🎯 RED ACCENTS TEST RESULTS:');
    console.log('==========================================');
    console.log(`Screenshot saved: /opt/pisignage/red-accents-test.png`);
    console.log(`Red border elements: ${redBorderElements}`);
    console.log(`Red accent buttons: ${redButtons}`);
    console.log(`Console errors: ${consoleErrors.length}`);
    console.log(`Background: ${backgroundColor === 'rgb(0, 0, 0)' ? 'BLACK ✅' : 'NOT BLACK ❌'}`);
    
    // Overall assessment
    const score = [
      redAccentVars.accent.includes('220, 38, 38') ? 1 : 0,
      redBorderElements >= 5 ? 1 : 0,
      redButtons >= 3 ? 1 : 0,
      backgroundColor === 'rgb(0, 0, 0)' ? 1 : 0,
      consoleErrors.length === 0 ? 1 : 0
    ].reduce((a, b) => a + b, 0);
    
    console.log(`\nOVERALL SCORE: ${score}/5`);
    
    if (score >= 4) {
      console.log('🎉 RED ACCENTS IMPLEMENTATION: EXCELLENT');
    } else if (score >= 3) {
      console.log('✅ RED ACCENTS IMPLEMENTATION: GOOD');
    } else {
      console.log('⚠️  RED ACCENTS IMPLEMENTATION: NEEDS IMPROVEMENT');
    }

  } catch (error) {
    console.error('❌ Test failed:', error.message);
  } finally {
    await browser.close();
  }
}

// Run the test
testRedAccents().catch(console.error);