
resource "yandex_iam_service_account" "dataproc-sa" {
  name        = "dataproc-sa"
  description = "Service account for Data Proc cluster"
}

resource "yandex_resourcemanager_folder_iam_binding" "dataproc" {
  folder_id = "<folder_id>" # Set folder ID
  role      = "mdb.dataproc.agent"
  members = [
    "serviceAccount:${yandex_iam_service_account.dataproc-sa.id}"
  ]
}

resource "yandex_resourcemanager_folder_iam_binding" "bucket-creator" {
  folder_id = "<folder_id>" # Set folder ID
  role      = "editor"
  members = [
    "serviceAccount:${yandex_iam_service_account.dataproc-sa.id}"
  ]
}

resource "yandex_iam_service_account_static_access_key" "s-key-dataproc" {
  service_account_id = yandex_iam_service_account.dataproc-sa.id
}

resource "yandex_storage_bucket" "bucket-dataproc" {
  depends_on = [
    yandex_resourcemanager_folder_iam_binding.bucket-creator
  ]

  bucket     = "bucket-dataproc"
  access_key = yandex_iam_service_account_static_access_key.s-key-dataproc.access_key
  secret_key = yandex_iam_service_account_static_access_key.s-key-dataproc.secret_key
}