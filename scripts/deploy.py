# SPDX-License-Identifier: BUSL-1.1
import os

from brownie import accounts, GovNftSugar


def main():
    if os.getenv('PROD'):
        account = accounts.load('sugar')
    else:
        account = accounts[0]

    GovNftSugar.deploy(os.getenv('GOVNFT_FACTORY_ADDRESS'), {'from': account})
