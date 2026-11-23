//! DCL Remoto — configuração do produto embutida no binário.
//!
//! O RustDesk OSS só aceita "cliente personalizado" via `custom.txt` assinado pela chave
//! privada do Server Pro (ver `read_custom_client` em common.rs). Aqui a mesma estrutura
//! JSON é compilada dentro do executável (`res/produto/produto.json`) e aplicada pelo mesmo
//! código do upstream, sem verificação de assinatura: o arquivo vem do nosso próprio fonte,
//! não de entrada externa.
//!
//! Servidor e chave próprios ficam em `override-settings` (custom-rendezvous-server,
//! relay-server, key): o usuário final não consegue trocá-los. Ver servidor/README.md.

/// Nome exibido ao usuário. O nome interno (`app-name`) usa hífen porque também nomeia o
/// serviço do Windows, a pasta de configuração e o esquema de URI, que não aceitam espaço.
pub const NOME_EXIBICAO: &str = "DCL Remoto";

const PRODUTO_JSON: &str = include_str!("../res/produto/produto.json");

pub fn aplicar() {
    crate::common::apply_custom_client_data(PRODUTO_JSON.as_bytes());
}

#[cfg(test)]
mod tests {
    #[test]
    fn json_valido() {
        let v: serde_json::Value = serde_json::from_str(super::PRODUTO_JSON).unwrap();
        let nome = v["app-name"].as_str().unwrap();
        assert!(!nome.is_empty());
        assert!(nome.chars().all(|c| c.is_ascii_alphanumeric() || c == '-'));
        assert_eq!(v["override-settings"]["allow-hide-cm"], "N");
        let k = v["override-settings"]["key"].as_str().unwrap();
        use hbb_common::base64::{engine::general_purpose::STANDARD, Engine as _};
        assert_eq!(STANDARD.decode(k).unwrap().len(), 32);
        assert!(!v["override-settings"]["custom-rendezvous-server"].as_str().unwrap().is_empty());
    }
}
