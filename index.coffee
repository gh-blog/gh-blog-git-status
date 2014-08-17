_   = require 'lodash'
git = require 'git-promise'
# @TODO: replace with Vinyl
{ File }   = require 'gulp-util'
through2 = require 'through2'
path = require 'path'


states =
    ' ' : 'unmodified'
    'M' : 'modified'
    'A' : 'added'
    'R' : 'renamed'
    'C' : 'copied'
    'D' : 'deleted'
    '?' : 'untracked'
    '!' : 'ignored'

toSpaceSeparated = (str) ->
    if typeof str is 'string'
        str
    else if _.isArray str
        ("\"#{el}\"" for el in str).join(' ')
    else throw new TypeError 'The specified parameter is neither
    a string nor an array'

strToArray = (str) ->
    str.split('\n').filter (line) ->
        line.length

arrayToObjects = (command) ->
    (lines) ->
        all = []
        lines.map (line) ->
            m = line.match /^(.)(.)\s(.*)/i
            status = states[m[1]] # Status of the index
            filename = m[3]
            { filename, status }

objectsToFiles = (cwd) ->
    (objects) ->
        objects.map (obj) ->
            file = new File path: obj.filename, cwd: cwd
            file.status = obj.status
            file

status = (options = { }) ->
    options = _.defaults options, cwd: process.cwd()
    { cwd, repo } = options

    if not repo
        throw new Error 'You must specifiy a working directory'

    processFile = (streamFile, enc, done) ->
        try
            if not streamFile.isDirectory()
                i = _.findIndex files, (file) ->
                    file.filename == streamFile.relative

                if i > -1
                    console.log 'HERE', streamFile.path, files[i].status
                    streamFile.status = files[i].status
                else
                    # File did not show up in git status,
                    # so we assume it was not modified
                    streamFile.status = states[' ']

            done null, streamFile
            files
        catch e
            # @TODO: debug
            console.log 'ERROR in git-status', e

    files = undefined
    resolved = no
    through2.obj (args...) ->
        processFile.bind this
        if resolved then return processFile args...
        cmd = 'git status --porcelain --untracked-files="all"'
        repo = path.resolve cwd, repo
        git cmd, cwd: repo
        .then strToArray
        .then arrayToObjects cmd
        .then (f) ->
            resolved = yes
            files = f
            processFile args...

module.exports = { status }