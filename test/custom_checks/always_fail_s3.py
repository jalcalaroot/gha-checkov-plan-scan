from typing import Any, Dict, List

from checkov.common.models.enums import CheckCategories, CheckResult
from checkov.terraform.checks.resource.base_resource_check import BaseResourceCheck

# Test-only: proves external-checks-dir is actually passed through to the
# checkov invocation, not that any real policy is enforced. Always fails
# on the fixture's aws_s3_bucket so the test can assert this specific ID
# shows up only when the input is set.


class AlwaysFailS3(BaseResourceCheck):
    def __init__(self) -> None:
        super().__init__(
            name="Test-only check that always fails, to prove external-checks-dir wiring",
            id="CKV2_CUSTOM_TEST_1",
            categories=[CheckCategories.GENERAL_SECURITY],
            supported_resources=["aws_s3_bucket"],
        )

    def scan_resource_conf(self, conf: Dict[str, List[Any]]) -> CheckResult:
        return CheckResult.FAILED


check = AlwaysFailS3()
