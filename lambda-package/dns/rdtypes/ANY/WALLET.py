# Copyright (C) Dnspython Contributors, see LICENSE for text of ISC license

import lambda.vendor.dns.immutable
import lambda.vendor.dns.rdtypes.txtbase


@lambda.vendor.dns.immutable.immutable
class WALLET(lambda.vendor.dns.rdtypes.txtbase.TXTBase):
    """WALLET record"""
