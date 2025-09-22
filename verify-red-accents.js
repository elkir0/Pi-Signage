#!/usr/bin/env node

/**
 * PiSignage Red Accents Source Code Verification
 * 
 * This script verifies that FREE.FR red accents are properly implemented
 * by analyzing the source code files directly.
 */

const fs = require('fs');
const path = require('path');

function analyzeFile(filePath) {
  if (!fs.existsSync(filePath)) {
    return { exists: false };
  }
  
  const content = fs.readFileSync(filePath, 'utf-8');
  
  return {
    exists: true,
    hasRedBorder: content.includes('border-red-600'),
    hasRedAccent: content.includes('text-red-500') || content.includes('bg-red-600'),
    hasRedHover: content.includes('hover:bg-red-700') || content.includes('hover:border-red-500'),
    hasPsCard: content.includes('ps-card') || content.includes('ps-card-accent'),
    hasPsBtn: content.includes('ps-btn-primary') || content.includes('ps-btn-secondary'),
    lineCount: content.split('\n').length
  };
}

function analyzeGlobalCSS() {
  const cssPath = '/opt/pisignage/src/app/globals.css';
  if (!fs.existsSync(cssPath)) {
    return { exists: false };
  }
  
  const content = fs.readFileSync(cssPath, 'utf-8');
  
  return {
    exists: true,
    hasRedVariables: content.includes('--ps-accent: #DC2626'),
    hasRedBorder: content.includes('border-red-600'),
    hasGlassCardRed: content.includes('glass-card') && content.includes('border-red-600'),
    hasPsCardAccent: content.includes('ps-card-accent'),
    hasRedGlow: content.includes('rgba(220, 38, 38'),
    lineCount: content.split('\n').length
  };
}

console.log('🔴 PiSignage RED ACCENTS Source Code Verification\n');
console.log('================================================\n');

// Check globals.css
console.log('📄 Analyzing globals.css...');
const cssAnalysis = analyzeGlobalCSS();
if (cssAnalysis.exists) {
  console.log(`   ✅ File exists (${cssAnalysis.lineCount} lines)`);
  console.log(`   ${cssAnalysis.hasRedVariables ? '✅' : '❌'} RED accent variables (#DC2626)`);
  console.log(`   ${cssAnalysis.hasRedBorder ? '✅' : '❌'} RED border utilities`);
  console.log(`   ${cssAnalysis.hasGlassCardRed ? '✅' : '❌'} Glass cards with red borders`);
  console.log(`   ${cssAnalysis.hasPsCardAccent ? '✅' : '❌'} ps-card-accent class`);
  console.log(`   ${cssAnalysis.hasRedGlow ? '✅' : '❌'} RED glow effects`);
} else {
  console.log('   ❌ File not found');
}

// Check components
console.log('\n📂 Analyzing Components...');
const components = [
  '/opt/pisignage/src/components/dashboard/Dashboard.tsx',
  '/opt/pisignage/src/components/media/MediaLibrary.tsx',
  '/opt/pisignage/src/components/youtube/YouTubeDownloader.tsx',
  '/opt/pisignage/src/components/playlist/PlaylistManager.tsx',
  '/opt/pisignage/src/components/settings/Settings.tsx',
  '/opt/pisignage/src/components/layout/Header.tsx'
];

let totalComponents = 0;
let componentsWithRedAccents = 0;

components.forEach(componentPath => {
  const name = path.basename(componentPath);
  const analysis = analyzeFile(componentPath);
  
  if (analysis.exists) {
    totalComponents++;
    const hasRedFeatures = analysis.hasRedBorder || analysis.hasRedAccent || analysis.hasRedHover;
    if (hasRedFeatures) componentsWithRedAccents++;
    
    console.log(`\n   📄 ${name}:`);
    console.log(`      ${analysis.hasPsCard ? '✅' : '⚠️ '} Uses ps-card classes`);
    console.log(`      ${analysis.hasPsBtn ? '✅' : '⚠️ '} Uses ps-btn classes`);
    console.log(`      ${analysis.hasRedBorder ? '✅' : '⚠️ '} Has red borders`);
    console.log(`      ${analysis.hasRedAccent ? '✅' : '⚠️ '} Has red accents`);
    console.log(`      ${analysis.hasRedHover ? '✅' : '⚠️ '} Has red hover effects`);
  } else {
    console.log(`   ❌ ${name}: File not found`);
  }
});

// Summary
console.log('\n🎯 VERIFICATION SUMMARY:');
console.log('========================');
console.log(`Components analyzed: ${totalComponents}`);
console.log(`Components with red accents: ${componentsWithRedAccents}`);
console.log(`CSS file status: ${cssAnalysis.exists ? 'EXISTS' : 'MISSING'}`);

// Calculate score
const cssScore = cssAnalysis.exists ? [
  cssAnalysis.hasRedVariables,
  cssAnalysis.hasRedBorder,
  cssAnalysis.hasGlassCardRed,
  cssAnalysis.hasPsCardAccent,
  cssAnalysis.hasRedGlow
].filter(Boolean).length : 0;

const componentScore = totalComponents > 0 ? (componentsWithRedAccents / totalComponents) * 5 : 0;
const totalScore = cssScore + Math.round(componentScore);

console.log(`\nCSS Score: ${cssScore}/5`);
console.log(`Component Score: ${Math.round(componentScore)}/5`);
console.log(`TOTAL SCORE: ${totalScore}/10`);

if (totalScore >= 8) {
  console.log('\n🎉 RED ACCENTS IMPLEMENTATION: EXCELLENT');
} else if (totalScore >= 6) {
  console.log('\n✅ RED ACCENTS IMPLEMENTATION: GOOD');
} else if (totalScore >= 4) {
  console.log('\n⚠️  RED ACCENTS IMPLEMENTATION: ACCEPTABLE');
} else {
  console.log('\n❌ RED ACCENTS IMPLEMENTATION: NEEDS WORK');
}

console.log('\n📋 RECOMMENDATIONS:');
if (cssScore < 5) {
  console.log('   - Ensure all CSS red accent utilities are properly defined');
}
if (componentScore < 4) {
  console.log('   - Add more red accent elements to components');
}
if (totalScore >= 8) {
  console.log('   - Implementation looks good! 🎉');
  console.log('   - Consider testing the interface visually');
}

console.log('\n🚀 Next step: Deploy and test visually on the Pi');
console.log('   ssh pi@192.168.1.103');
console.log('   cd /opt/pisignage && git pull && sudo pm2 restart pisignage-web');