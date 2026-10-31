"use strict";

var assert = require("assert");
var childProcess = require("child_process");
var fs = require("fs");
var os = require("os");
var path = require("path");

function read(file) {
    return fs.readFileSync(path.join(__dirname, "..", file), "utf8");
}

function fpmPool(script, name) {
    var match = script.match(new RegExp("cat <<EOF > /etc/php/\\$\\{PhpVer\\}/fpm/pool\\.d/" +
        name + "\\.conf\\n([\\s\\S]*?)\\nEOF"));
    assert.ok(match, "Missing FPM pool: " + name);
    var generated = childProcess.execFileSync("bash", ["-c",
        "PhpVer=8.3\ncat <<EOF\n" + match[1] + "\nEOF"], {encoding: "utf8"});
    var settings = {};
    generated.split("\n").forEach(function (line) {
        var setting = line.match(/^([^=]+)=\s*(.+)$/);
        if (setting) {
            settings[setting[1].trim()] = setting[2].trim();
        }
    });
    assert.ok(generated.indexOf("[" + name + "]\n") === 0);
    return settings;
}

function redisConfiguration(script, auth) {
    var match = script.match(/    if \[ "\$redisAuth" != "None" \]; then\n[\s\S]*?\n    fi/);
    assert.ok(match, "Missing conditional Redis session configuration");
    var directory = fs.mkdtempSync(path.join(os.tmpdir(), "moodle-redis-test-"));
    var config = path.join(directory, "config.php");
    var original = "<?php\n$CFG = new stdClass();\n" + new Array(30).join("\n");
    fs.writeFileSync(config, original);
    try {
        childProcess.execFileSync("bash", ["-c",
            "set -eu\nredisAuth=$1\nredisDns=redis.example.invalid\n" +
            "create_redis_configuration_in_moodledata_muc_config_php() { :; }\n" +
            match[0].replace(/\/moodle\/html\/moodle\/config\.php/g, "\"$2\""),
            "redis-test", auth, config], {encoding: "utf8"});
        return {original: original, generated: fs.readFileSync(config, "utf8")};
    } finally {
        fs.unlinkSync(config);
        fs.rmdirSync(directory);
    }
}

function runCron(command, script, shortened) {
    var args = command.slice(1, 4);
    if (shortened) {
        args[1] = "0.2";
        args[2] = "0.2";
    }
    var result = childProcess.spawnSync(command[0], args.concat(["/bin/sh", "-c", script]),
        {encoding: "utf8", timeout: 5000});
    assert.ifError(result.error);
    return result;
}

function runTests() {
    var installer = read("scripts/install_moodle.sh");
    var webserver = read("scripts/setup_webserver.sh");
    var passed = 0;
    function check(name, test) {
        test();
        passed += 1;
        console.log("PASS " + name);
    }

    check("controller generates a valid bounded dynamic FPM pool", function () {
        var pool = fpmPool(installer, "www");
        assert.strictEqual(pool.pm, "dynamic");
        assert.strictEqual(pool["pm.max_children"], "40");
        assert.strictEqual(pool["pm.start_servers"], "8");
        assert.strictEqual(pool["pm.min_spare_servers"], "4");
        assert.strictEqual(pool["pm.max_spare_servers"], "12");
        assert.ok(Number(pool["pm.min_spare_servers"]) <= Number(pool["pm.start_servers"]));
        assert.ok(Number(pool["pm.start_servers"]) <= Number(pool["pm.max_spare_servers"]));
        assert.ok(Number(pool["pm.max_spare_servers"]) <= Number(pool["pm.max_children"]));
    });

    check("frontend FPM pools retain valid static worker counts", function () {
        ["www", "backup"].forEach(function (name) {
            var pool = fpmPool(webserver, name);
            assert.strictEqual(pool.pm, "static");
            assert.ok(Number(pool["pm.max_children"]) > 0);
            assert.strictEqual(pool["pm.start_servers"], pool["pm.max_children"]);
        });
    });

    check("Redis sessions generate a ten-second connection timeout", function () {
        var config = redisConfiguration(installer, "test-password").generated;
        assert.ok(config.indexOf("$CFG->session_redis_connection_timeout = 10;") !== -1);
        assert.ok(config.indexOf("$CFG->session_handler_class = '\\core\\session\\redis';") !== -1);
    });

    check("disabled Redis leaves the session configuration unchanged", function () {
        var config = redisConfiguration(installer, "None");
        assert.strictEqual(config.generated, config.original);
    });

    var cron = installer.match(/echo '([^'\n]*cron\.php[^'\n]*)' > \/etc\/cron\.d\/moodle-cron/);
    assert.ok(cron, "Missing Moodle cron entry");
    var fields = cron[1].split(/\s+/);
    var command = fields.slice(6, 12);
    check("cron retains scheduling, logging and the 1800/30-second timeout bounds", function () {
        assert.deepStrictEqual(fields.slice(0, 6), ["*", "*", "*", "*", "*", "www-data"]);
        assert.deepStrictEqual(command, ["/usr/bin/timeout", "-k", "30", "1800",
            "/usr/bin/php", "/moodle/html/moodle/admin/cli/cron.php"]);
        assert.deepStrictEqual(fields.slice(12), ["2>&1", "|", "/usr/bin/logger",
            "-p", "local2.notice", "-t", "moodle"]);
    });

    check("cron timeout preserves normal success and failure exit codes", function () {
        [0, 7].forEach(function (status) {
            assert.strictEqual(runCron(command, "exit " + status, false).status, status);
        });
    });

    check("cron timeout terminates a hung process", function () {
        assert.strictEqual(runCron(command, "exec sleep 60", true).status, 124);
    });

    check("cron timeout forcibly kills a process ignoring SIGTERM", function () {
        var result = runCron(command, "trap '' TERM; exec sleep 60", true);
        assert.ok(result.status === 137 || result.signal === "SIGKILL");
    });

    check("unsupported php-xmlrpc stays out of provisioning scripts", function () {
        [installer, webserver, read("scripts/helper_functions.sh")].forEach(function (script) {
            assert.ok(!/\bphp(?:[0-9.]+)?-xmlrpc\b/.test(script));
        });
    });

    var deployment = JSON.parse(read("azuredeploy.json"));
    check("deployment resolves the official Ubuntu 24.04 AMD64 Gen2 image", function () {
        assert.deepStrictEqual(deployment.variables.moodleCommon.osType, {
            offer: "ubuntu-24_04-lts",
            publisher: "Canonical",
            sku: "[parameters('ubuntuVersion')]",
            version: "latest"
        });
        assert.strictEqual(deployment.parameters.ubuntuVersion.defaultValue, "server");
        assert.deepStrictEqual(deployment.parameters.ubuntuVersion.allowedValues, ["server"]);
    });

    check("migration passes the same supported image SKU to the main deployment", function () {
        var migration = JSON.parse(read("migration/azuredeploy-migration.json"));
        assert.deepStrictEqual(migration.parameters.ubuntuVersion.allowedValues,
            deployment.parameters.ubuntuVersion.allowedValues);
        assert.strictEqual(migration.parameters.ubuntuVersion.defaultValue, "server");
        assert.strictEqual(migration.resources[0].properties.parameters.ubuntuVersion.value,
            "[parameters('ubuntuVersion')]");
    });

    console.log(passed + " deployment regression checks passed.");
}

module.exports = runTests;
if (require.main === module) {
    runTests();
}
