# Copyright (C) Dnspython Contributors, see LICENSE for text of ISC license

import lambda.vendor.dns.immutable
import lambda.vendor.dns.rdtypes.tlsabase


@lambda.vendor.dns.immutable.immutable
class TLSA(lambda.vendor.dns.rdtypes.tlsabase.TLSABase):
    """TLSA record"""
