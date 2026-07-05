terraform {
    backend "s3" {
        bucket = "amirul-logic-matrix"
        key = "terraform/state.tfstate"
        region = "us-east-1"
        encrypt = true
        use_lockfile = true
    }
}