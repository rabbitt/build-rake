{ File } = require 'atom'
fs = require('fs')
path = require('path')
child_process = require('child_process')

exports.provideRakeBuilder = ->
  class RakeBuildProvider
    constructor: (@cwd) ->

    getNiceName: ->
      'Rake'

    isEligible: ->
      files = ['Rakefile', 'rakefile', 'Rakefile.rb', 'rakefile.rb']
      found = files.map (file) => path.join(@cwd, file)
        .filter(fs.existsSync)

      found.length > 0

    _determineRVM: ->
      new File(path.join(process.env['HOME'], '.rvm'))
      .exists()
        .then (rvmDirExists) =>
          return '' unless rvmDirExists
          console.log("Found an RVM directory")
          process.env['JRUBY_OPTS'] = '--2.0 --dev'

          files = [ '.rvmrc', '.versions.conf', '.ruby-version', '.rbfu-version', '.rbenv-version' ]
          futures = (new File(path.join(@cwd, file)).exists() for file in files)

          Promise.all(futures).then (file_values) =>
            for exists, index in file_values
              console.log("checking -> #{path.join(@cwd, files[index])} = #{exists.toString()}")
              return true if exists
            return false
          .then (have_config) =>
            process.env['rvm_in_flag'] = ''
            if have_config then console.log("found a valid version file") else console.log("no valid version file")
            return if have_config then "rvm in #{@cwd} do " else "rvm default exec "

    settings: ->
      new Promise (resolve, reject) =>
        process.env['JRUBY_OPTS'] = '--2.0 --dev'

        new Promise (resolve, reject) =>
          resolve(if /^win/.test(process.platform) then "windows" else "unix")
        .then (platform) ->
          switch platform
            when 'unix'    then "rake"
            when 'windows' then "rake.bat"
        .then (command) =>
          @_determineRVM(@cwd).then (prefix) =>
            console.log "running command in #{@cwd} -> #{prefix}#{command}"
            "#{prefix}#{command}"
        .then (rake_exec) =>
          rake_t = "#{rake_exec} -T"
          child_process.exec rake_t, {cwd: @cwd}, (error, stdout, stderr) ->
            reject(error) if error?
            config = []
            stdout.split("\n").forEach (line) ->
              if (m = /^rake (\S+)\s*#\s*(\S+.*)/.exec(line))?
                args = rake_exec.split(/\s+/).concat([m[1]])
                command = args.shift()
                config.push
                  name: "rake #{m[1]} - #{m[2]}"
                  exec: command
                  sh: false
                  args: args
            resolve(config)
