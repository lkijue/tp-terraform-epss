mock "tfplan/v2" {
  module {
    source = "../../testdata/mock-tfplan-dev-ok.sentinel"
  }
}

mock "tfrun" {
  data = {
    workspace = {
      name = "cloudtech-dev"
    }
  }
}

test {
  rules = {
    main = true
  }
}
