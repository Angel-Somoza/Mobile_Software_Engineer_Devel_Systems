package com.example.qr_scanner.parser


internal sealed interface QrParseResult {
    //data class para saber si es valido
    data class valid(val productId : Int) : QrParseResult
    //data class para saber si no es valido
    data class invalid(val reason : QrParserReason) : QrParseResult

}