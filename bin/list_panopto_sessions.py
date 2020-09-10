#!/usr/bin/env python3

import cass
import cass_env

from panopto_folders import PanoptoFolders
from panopto_oauth2 import PanoptoOAuth2

from requests import Session

panopto_env   = cass_env.load('panopto')
server        = panopto_env['PANOPTO_SERVER']
client_id     = panopto_env['PANOPTO_CLIENT_ID']
folder_id     = panopto_env['PANOPTO_FOLDER_ID']

client_secret = cass_env.load_secret('panopto_client')
cache_dir     = cass.cache('panopto')

def main():
    session        = Session()
    session.verify = True
    oauth2         = PanoptoOAuth2(server, client_id, client_secret, cache_dir)
    folders        = PanoptoFolders(server, True, oauth2)
    folder         = folders.get_folder(folder_id)
    list_sessions(folders, folder)

def list_sessions(folders, folder):
    for entry in folders.get_sessions(folder['Id']):
        print('{} {}'.format(entry['Id'], entry['Name']))

if __name__ == '__main__':
    main()
