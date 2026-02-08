<?php
/**
 * GLPI Prerequisites Verification Script
 */

echo "========================================\n";
echo "GLPI Prerequisites Verification\n";
echo "========================================\n\n";

// Check PHP Version
echo "✓ PHP Version Check:\n";
$phpVersion = phpversion();
echo "  Current: PHP $phpVersion\n";
if (version_compare($phpVersion, '8.2.0', '>=')) {
    echo "  Status: ✅ PASS (>= 8.2 required)\n\n";
} else {
    echo "  Status: ❌ FAIL (>= 8.2 required)\n\n";
}

// Mandatory Extensions
echo "✓ Mandatory PHP Extensions:\n";
$mandatory = [
    'dom', 'fileinfo', 'filter', 'libxml', 'simplexml', 
    'xmlreader', 'xmlwriter', 'bcmath', 'curl', 'gd', 
    'intl', 'mbstring', 'mysqli', 'openssl', 'zlib'
];

foreach ($mandatory as $ext) {
    $loaded = extension_loaded($ext);
    $status = $loaded ? '✅' : '❌';
    echo "  $status $ext\n";
}

// Suggested Extensions
echo "\n✓ Suggested PHP Extensions:\n";
$suggested = [
    'bz2', 'phar', 'zip', 'exif', 'ldap', 'Zend OPcache'
];

foreach ($suggested as $ext) {
    $extName = strtolower(str_replace(' ', '', $ext));
    $loaded = extension_loaded($extName);
    $status = $loaded ? '✅' : '⚠️';
    echo "  $status $ext\n";
}

// PHP Configuration
echo "\n✓ PHP Configuration:\n";
$configs = [
    'memory_limit' => ini_get('memory_limit'),
    'max_execution_time' => ini_get('max_execution_time'),
    'post_max_size' => ini_get('post_max_size'),
    'upload_max_filesize' => ini_get('upload_max_filesize'),
    'session.auto_start' => ini_get('session.auto_start'),
];

foreach ($configs as $key => $value) {
    echo "  • $key: $value\n";
}

echo "\n========================================\n";
echo "Verification Complete!\n";
echo "========================================\n";
?>
