Package.describe({
  name: 'urbanetic:bismuth-schema-utility',
  summary: 'Utilites for schemas and collections in Bismuth.',
  git: 'https://github.com/urbanetic/bismuth-schema-utility.git',
  version: '0.2.1'
});

Package.on_use(function(api) {
  api.versionsFrom('METEOR@0.9.0');
  api.use([
    'check',
    'coffeescript',
    'underscore',
    'aldeed:simple-schema@1.1.0',
    'aramk:requirejs@2.1.15_1',
    'aramk:utility@0.6.0'
  ], ['client', 'server']);
  api.use([
    'urbanetic:atlas@0.8.2'
  ], ['client', 'server'], {weak: true});
  api.addFiles([
    'src/ParamUtils.coffee',
    'src/SchemaUtils.coffee',
  ], ['client', 'server']);
  api.export([
    'ParamUtils',
    'SchemaUtils',
  ], ['client', 'server']);
});
