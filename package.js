Package.describe({
  name: 'urbanetic:bismuth-schema-utility',
  summary: 'Utilities for schemas and collections in Bismuth.',
  git: 'https://github.com/urbanetic/bismuth-schema-utility.git',
  version: '1.0.0'
});

Package.on_use(function(api) {
  api.versionsFrom('METEOR@1.6.1');
  api.use([
    'check',
    'coffeescript',
    'underscore',
    'aldeed:simple-schema@1.1.0',
    'aramk:requirejs@2.1.15_1',
    'urbanetic:utility@2.0.0'
  ], ['client', 'server']);
  api.use([
    'urbanetic:atlas@0.8.2'
  ], ['client', 'server'], {weak: true});
  api.addFiles([
    'src/ParamUtils.coffee',
    'src/SchemaUtils.coffee'
  ], ['client', 'server']);
  api.export([
    'ParamUtils',
    'SchemaUtils'
  ], ['client', 'server']);
});
