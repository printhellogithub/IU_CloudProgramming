# Copyright (C) Dnspython Contributors, see LICENSE for text of ISC license

import lambda.vendor.dns.immutable
import lambda.vendor.dns.rdtypes.svcbbase


@lambda.vendor.dns.immutable.immutable
class SVCB(lambda.vendor.dns.rdtypes.svcbbase.SVCBBase):
    """SVCB record"""
