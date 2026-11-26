package com.example.covoiturage

interface Platform {
    val name: String
}

expect fun getPlatform(): Platform