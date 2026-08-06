# Copyright (C) Dnspython Contributors, see LICENSE for text of ISC license

from typing import Any, Dict, List, Tuple

import lambda.vendor.dns._features
import lambda.vendor.dns.asyncbackend

if lambda.vendor.dns._features.have("doq"):
    from lambda.vendor.dns._asyncbackend import NullContext
    from lambda.vendor.dns.quic._asyncio import AsyncioQuicConnection as AsyncioQuicConnection
    from lambda.vendor.dns.quic._asyncio import AsyncioQuicManager
    from lambda.vendor.dns.quic._asyncio import AsyncioQuicStream as AsyncioQuicStream
    from lambda.vendor.dns.quic._common import AsyncQuicConnection  # pyright: ignore
    from lambda.vendor.dns.quic._common import AsyncQuicManager as AsyncQuicManager
    from lambda.vendor.dns.quic._sync import SyncQuicConnection  # pyright: ignore
    from lambda.vendor.dns.quic._sync import SyncQuicStream  # pyright: ignore
    from lambda.vendor.dns.quic._sync import SyncQuicManager as SyncQuicManager

    have_quic = True

    def null_factory(
        *args,  # pylint: disable=unused-argument
        **kwargs,  # pylint: disable=unused-argument
    ):
        return NullContext(None)

    def _asyncio_manager_factory(
        context, *args, **kwargs  # pylint: disable=unused-argument
    ):
        return AsyncioQuicManager(*args, **kwargs)

    # We have a context factory and a manager factory as for trio we need to have
    # a nursery.

    _async_factories: Dict[str, Tuple[Any, Any]] = {
        "asyncio": (null_factory, _asyncio_manager_factory)
    }

    if lambda.vendor.dns._features.have("trio"):
        import trio

        # pylint: disable=ungrouped-imports
        from lambda.vendor.dns.quic._trio import TrioQuicConnection as TrioQuicConnection
        from lambda.vendor.dns.quic._trio import TrioQuicManager
        from lambda.vendor.dns.quic._trio import TrioQuicStream as TrioQuicStream

        def _trio_context_factory():
            return trio.open_nursery()

        def _trio_manager_factory(context, *args, **kwargs):
            return TrioQuicManager(context, *args, **kwargs)

        _async_factories["trio"] = (_trio_context_factory, _trio_manager_factory)

    def factories_for_backend(backend=None):
        if backend is None:
            backend = lambda.vendor.dns.asyncbackend.get_default_backend()
        return _async_factories[backend.name()]

else:  # pragma: no cover
    have_quic = False

    class AsyncQuicStream:  # type: ignore
        pass

    class AsyncQuicConnection:  # type: ignore
        async def make_stream(self) -> Any:
            raise NotImplementedError

    class SyncQuicStream:  # type: ignore
        pass

    class SyncQuicConnection:  # type: ignore
        def make_stream(self) -> Any:
            raise NotImplementedError


Headers = List[Tuple[bytes, bytes]]
