<!doctype html>
<html>
<head>
    <title>php λ</title>
    <link rel="icon" href="https://aws.amazon.com/favicon.ico" />
</head>
<body>

<?php

// https://bref.sh/docs/environment/php.html

// PHP Version 7.3.7


// GET https://905zjo5e05.execute-api.eu-central-1.amazonaws.com/test/blabla?k=v
// 
// $_SERVER['HTTP_X_FORWARDED_PROTO']   https
// $_SERVER['HTTP_X_FORWARDED_PORT']    443
// $_SERVER['HTTP_X_FORWARDED_FOR']     my-ip, 54.182.255.85 - WTF ?
// 
// $_SERVER['TZ']               :UTC
// $_SERVER['foo']              bar
// $_SERVER['AWS_REGION']       eu-central-1
// $_SERVER['AWS_LAMBDA_FUNCTION_MEMORY_SIZE'] 128
// $_SERVER['_HANDLER']         index.php
// $_SERVER['HTTP_HOST']        905zjo5e05.execute-api.eu-central-1.amazonaws.com
// $_SERVER['HTTP_USER_AGENT']  Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/79.0.3945.79 Safari/537.36
// $_SERVER['SERVER_NAME']      905zjo5e05.execute-api.eu-central-1.amazonaws.com
// $_SERVER['SERVER_ADDR']      127.0.0.1
// $_SERVER['SERVER_PORT']      443
// $_SERVER['REMOTE_ADDR']      127.0.0.1
// $_SERVER['REMOTE_PORT']      443
// $_SERVER['SCRIPT_FILENAME']  /var/task/index.php
// $_SERVER['REQUEST_METHOD']   GET
// $_SERVER['REQUEST_URI']      /blabla?k=v
// $_SERVER['PATH_INFO']        /blabla
// $_SERVER['PHP_SELF']         /blabla
// $_SERVER['QUERY_STRING']     k=v

// echo 'ы';
// phpinfo();

// $e = new Exception();
// echo '<pre>';
// echo $e->getTraceAsString();

echo (new DateTimeImmutable())->format('Y-m-d H:i:s') . PHP_EOL;
echo '<hr />' . PHP_EOL;
echo '<pre>';
var_export(glob('*'));
echo '</pre>';

?>
    </body>
</html>
