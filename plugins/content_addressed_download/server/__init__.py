#!/usr/bin/env python
# -*- coding: utf-8 -*-

###############################################################################
#  Copyright Kitware Inc.
#
#  Licensed under the Apache License, Version 2.0 ( the "License" );
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
###############################################################################

from girder import events
from girder.api import access
from girder.api.describe import describeRoute, Description
from girder.api.v1.file import File
from girder.utility import assetstore_utilities
from girder.utility.model_importer import ModelImporter


class HashedFile(File):
    def __init__(self, apiRoot):
        super(File, self).__init__()

        self.resourceName = 'file'
        apiRoot.file.route('GET', ('content', ':algo', ':hash', 'download'),
                           self.downloadWithHash)

    @access.public
    @describeRoute(
        Description('Download a file by its hash.')
        .param('algo', 'The type of the given hash.', paramType='path')
        .param('hash', 'The hash of the file to download.', paramType='path')
        .errorResponse()
        .errorResponse('Read access was denied on the file.', 403)
    )
    def downloadWithHash(self, algo, hash, params):
        # TODO
        pass


def calculate_hash(event):
    # TODO
    pass


def load(info):
    ModelImporter.model('file').ensureIndices(
        ['hash.md5', 'hash.sha1', 'hash.sha224', 'hash.sha256', 'hash.sha384', 'hash.sha512']
        + assetstore_utilities.fileIndexFields())
    ModelImporter.model('file').reconnect()

    HashedFile(info['apiRoot'])

    events.bind('TODO', 'calculate_hash', calculate_hash)
