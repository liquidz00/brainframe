data "tls_certificate" "hcp" {
  url = "https://app.terraform.io"
}

resource "aws_iam_openid_connect_provider" "hcp" {
  url             = "https://app.terraform.io"
  client_id_list  = ["aws.workload.identity"]
  thumbprint_list = [data.tls_certificate.hcp.certificates[0].sha1_fingerprint]
}

data "aws_iam_policy_document" "monitor_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.hcp.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "app.terraform.io:aud"
      values   = ["aws.workload.identity"]
    }

    condition {
      test     = "StringLike"
      variable = "app.terraform.io:sub"
      values   = ["organization:liquidzoo:project:brainframe:workspace:monitor:run_phase:*"]
    }
  }
}

resource "aws_iam_role" "monitor_runner" {
  name               = "brainframe-hcp-monitor"
  assume_role_policy = data.aws_iam_policy_document.monitor_trust.json
}

resource "aws_iam_role_policy_attachment" "monitor_runner_admin" {
  role       = aws_iam_role.monitor_runner.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
