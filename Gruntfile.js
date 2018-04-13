var grunt = require('grunt');
require('load-grunt-tasks')(grunt);

var templates = ['**/*.json'];

grunt.initConfig({
  jshint: {
      files: templates,
      options: {
          jshintrc: '.jshintrc'
      }
  },
  jscs: {
      files: {
          src: templates
      },
      options: {
          config: '.jscsrc',
          esnext: true
      }
  },
  jsbeautifier: {
      test: {
          files: {
              src: templates
          },
          options: {
              mode: 'VERIFY_ONLY',
              config: '.beautifyrc'
          }
      },
      lint: {
          files: {
              src: templates
          },
          options: {
              mode: 'VERIFY_ONLY',
              config: '.beautifyrc'
          }
      },
      reformat: {
          files: {
              src: templates
          },
          options: {
              mode: 'VERIFY_AND_WRITE',
              config: '.beautifyrc'
          }
      },
      write: {
          files: {
              src: templates
          },
          options: {
              config: '.beautifyrc'
          }
      }
  }
});
grunt.registerTask('test', ['jshint', 'jscs', 'jsbeautifier:test', 'jsbeautifier:write']);
