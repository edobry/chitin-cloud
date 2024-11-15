function gcloudConfigPath() {
    gcloud info --format="get(config.paths.active_config_path)"
}
