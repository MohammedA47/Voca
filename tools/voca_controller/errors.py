"""Typed exception hierarchy for voca_controller."""


class VocaControllerError(Exception):
    pass


class LeaseHeldError(VocaControllerError):
    """Lease is held by a live process."""


class LeaseTokenMismatchError(VocaControllerError):
    """Fencing token does not match stored token."""


class UncertainOpBlocksError(VocaControllerError):
    """Uncertain supervised operation blocks lease acquisition."""


class StatePathError(VocaControllerError):
    """State directory path is invalid or unsafe."""


class InvalidApprovalError(VocaControllerError):
    """Approval record is missing required fields or has mismatched digest."""


class ApprovalGateError(VocaControllerError):
    """Required approval gate has not been granted."""


class SpecChangedError(VocaControllerError):
    """Spec digest changed; existing execution approval invalidated."""


class MaxCorrectionsError(VocaControllerError):
    """Correction count at maximum; task moved to awaiting-human."""


class ReviewerConflictError(VocaControllerError):
    """Reviewer adapter must differ from writer adapter."""


class ScopeViolationError(VocaControllerError):
    """File changes outside authorized scope detected."""


class InfraRetryExhaustedError(VocaControllerError):
    """Infrastructure retry limit reached."""


class RepoVerificationError(VocaControllerError):
    """Remote repo name/ID does not match expected values."""


class InvalidTransitionError(VocaControllerError):
    """Requested state transition is not allowed from current state."""


class AdapterError(VocaControllerError):
    """Adapter launch or execution failure."""


class AuthFailureError(AdapterError):
    """Authentication failure detected; no retry allowed."""
