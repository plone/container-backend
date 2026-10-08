"""Store a blob larger than the S3 threshold in the ZODB root.

Run with ``zconsole run``, which provides ``app``.
"""

import transaction
from ZODB.blob import Blob

blob = Blob()
with blob.open("w") as fh:
    fh.write(b"x" * 200 * 1024)

app._p_jar.root()["s3blob-test"] = blob  # noqa: F821
transaction.commit()
print("blob committed")
