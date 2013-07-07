###
Copyright (c) 2013, Alexander Cherniuk <ts33kr@gmail.com>
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
###

_ = require "lodash"
wrench = require "wrench"
colors = require "colors"
logger = require "winston"
paths = require "path"

# This method is the base method for very important functionality.
# It scans the supplied directory, find all the modules there and
# return an object, where keys are names of modules minus the ext.
# This is used to build up entire module hierarchy of the framework.
collectModules = (directory) ->
    c = ".coffee".toLowerCase()
    ext = (name) -> paths.extname name
    sym = (name) -> paths.basename name, c
    isSupported = (name) -> ext(name) is c
    directory = "#{__dirname}/#{directory}"
    ingest = (x) -> require "#{directory}/#{x}"
    scanSync = wrench.readdirSyncRecursive
    scanned = scanSync directory.toString()
    supported = _.filter scanned, isSupported
    modules = _.map supported, ingest
    symbols = _.map supported, sym
    _.object symbols, modules

# Build up the entire module hierarchy of the framework. Please do
# refer to the `collectModules` method implementation for more
# information on how this is being done. See the modules in the
# framework library to see the structure of the built hieararchy.
module.exports.nucleus = collectModules "library/nucleus"
module.exports.visuals = collectModules "library/visuals"
module.exports.widgets = collectModules "library/widgets"
