# Copyright (C) Dnspython Contributors, see LICENSE for text of ISC license

import lambda.vendor.dns.immutable
import lambda.vendor.dns.rdtypes.svcbbase


@lambda.vendor.dns.immutable.immutable
class HTTPS(lambda.vendor.dns.rdtypes.svcbbase.SVCBBase):
    """HTTPS record"""
