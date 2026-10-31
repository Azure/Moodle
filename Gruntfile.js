var grunt = require('grunt');
require('load-grunt-tasks')(grunt);

var templates = ['nested/*.json', 'managedApplication/*.json', 'loadtest/*.json', '*.json'];

grunt.initConfig({
  jshint: {
      files: templates.concat(['tests/*.js']),
      options: {
          jshintrc: '.jshintrc'
      }
  }
});
grunt.registerTask('deployment-regressions', function () {
    require('./tests/deployment-regressions')();
});
grunt.registerTask('test', ['jshint', 'deployment-regressions']);
