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

import os

from .. import base
from girder.constants import SettingKey
from girder.utility import config, mail_utils


def setUpModule():
    pluginRoot = os.path.join(os.path.dirname(os.path.dirname(__file__)),
                              'test_plugins')
    conf = config.getConfig()
    conf['plugins'] = {'plugin_directory': pluginRoot}
    base.enabledPlugins.append('mail_test')

    base.startServer()


def tearDownModule():
    base.stopServer()


class MailTestCase(base.TestCase):
    """
    Test the email utilities.
    """

    def testEmailAdmins(self):
        self.assertTrue(base.mockSmtp.isMailQueueEmpty())

        admin1, admin2 = [self.model('user').createUser(
            firstName='Admin%d' % i, lastName='Admin', login='admin%d' % i,
            password='password', admin=True, email='admin%d@admin.com' % i)
            for i in range(2)]

        # Set the email from address
        self.model('setting').set(SettingKey.EMAIL_FROM_ADDRESS, 'a@test.com')

        # Test sending email to admin users
        mail_utils.sendEmail(text='hello', toAdmins=True)
        self.assertTrue(base.mockSmtp.waitForMail())

        lines = base.mockSmtp.getMail().strip().splitlines()
        self.assertTrue('Subject: [no subject]' in lines)
        self.assertTrue('To: admin0@admin.com, admin1@admin.com' in lines)
        self.assertTrue('From: a@test.com' in lines)
        self.assertEqual(lines[-1], 'hello')

        # Test sending email to multiple recipients
        self.assertTrue(base.mockSmtp.isMailQueueEmpty())
        mail_utils.sendEmail(to=('a@abc.com', 'b@abc.com'), text='world',
                             subject='Email alert')
        self.assertTrue(base.mockSmtp.waitForMail())

        lines = base.mockSmtp.getMail().strip().splitlines()
        self.assertTrue('Subject: Email alert' in lines)
        self.assertTrue('To: a@abc.com, b@abc.com' in lines)
        self.assertTrue('From: a@test.com' in lines)
        self.assertEqual(lines[-1], 'world')

        # Pass nonsense in the "to" field, check exception
        x = 0
        try:
            mail_utils.sendEmail(text='hello', to=None)
        except Exception as e:
            x = 1
            self.assertEqual(
                e.args[0], 'You must specify a "to" address or list of '
                'addresses or set toAdmins=True when calling sendEmail.')

        self.assertEqual(x, 1)

    def testPluginTemplates(self):
        val = 'OVERRIDE CORE FOOTER'
        self.assertEqual(mail_utils.renderTemplate('_footer.mako').strip(), val)

        # Make sure it also works from in-mako import statements
        content = mail_utils.renderTemplate('temporaryAccess.mako', {
            'url': 'x'
        })
        self.assertTrue(val in content)
