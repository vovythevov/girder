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
from girder.utility import assetstore_utilities, hash_state
from girder.utility.model_importer import ModelImporter

import hashlib

class HashedFile(File):

    """
    List of the supported algorithms by the content_addressed_download
    plugin.
    """
    SupportedHashes = [
        'md5',
        'sha1',
        'sha224',
        'sha256',
        'sha384',
        'sha512' # Already supported, NEED TO NOT RE-DO IT ?
    ]

    def __init__(self, apiRoot):
        super(File, self).__init__()

        self.resourceName = 'file'
        apiRoot.file.route('GET', ('content', ':algo', ':hash', 'download'),
                           self.downloadWithHash)

    @access.public
    @describeRoute(
        Description('Download a file by its hash.')
        .param('algo', 'The type of the given hash.',
               paramType='path', enum=SupportedHashes)
        .param('hash', 'The hash of the file to download.',
                paramType='path')
        .errorResponse()
        .errorResponse('Read access was denied on the file.', 403)
    )
    def downloadWithHash(self, algo, hash, params):
        print('Download with %s %s' %(algo, hash))

        query = { algo : hash }
        fileModel = self.model('file')
        file = fileModel.findOne(query)
        return fileModel.download(file)


def finalize_hash(event):
    """
    Finalize all the hashes and update the file.
    :param event:
    """

    file = event.info['file']
    upload = event.info['upload']

    upload_state_key = '%sstate'
    for hash_type in HashedFile.SupportedHashes:
        state = upload[upload_state_key % hash_type]
        checksum = hash_state.restoreHex(state, hash_type)
        file[hash_type] = checksum.hexdigest()

    ModelImporter.model('file').updateFile(file)
    print(file)

BUF_SIZE = 65536 # TODO IMPORT THAT FROM FILE ASSESTORE ?

def update_hash(event):
    """
    Update the hash on the upload document every time a chunk is uploaded.
    :param event:
    """

    upload = event.info
    checksums = []
    upload_state_key = '%sstate'
    for hash_type in HashedFile.SupportedHashes:
        try:
            state = upload[upload_state_key % hash_type]
        except KeyError:
            state = hash_state.serializeHex(hashlib.new(hash_type))

        checksums.append(hash_state.restoreHex(state, hash_type))

    # Let's make it work on filesystems for now
    with open(upload['tempFile'], 'rb') as tempFile:
        for data in tempFile.read(BUF_SIZE):
            for checksum in checksums:
                checksum.update(data)

    for i, hash_type in enumerate(HashedFile.SupportedHashes):
        upload[upload_state_key % hash_type] =\
            hash_state.serializeHex(checksums[i])

    ModelImporter.model('upload').save(upload, triggerEvents=False)


def load(info):

    indicesList = []
    for hash_type in HashedFile.SupportedHashes:
        indicesList.append('hash.%s' %hash_type)

    ModelImporter.model('file').ensureIndices(
        indicesList + assetstore_utilities.fileIndexFields())
    ModelImporter.model('file').reconnect()

    HashedFile(info['apiRoot'])

    events.bind('model.upload.save', 'update_hash', update_hash)
    events.bind(
        'model.file.finalizeUpload.before', 'finalize_hash', finalize_hash)