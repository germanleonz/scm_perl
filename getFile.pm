#!/usr/bin/perl

package getFile;
use lib qw(.);
use lib qw(./lib/perl5/site_perl/5.12.4/);
use lib qw(./lib/lib/perl5/site_perl/5.12.4);
use strict;
use Net::SFTP::Foreign;
use Digest::MD5;
use constant K => 1; 
my $raiz = '/tmp';


sub commit {
    my $archivo = shift;
    my $checksum = &checksum($archivo);
    my ($version, $checksumL,@replicas) = &getRep($archivo);
    
    if ($checksum ne $checksumL){
        &send2rep($archivo,$version+1,@replicas);
        return 0;
    }else{
        return 1;
    }
}

sub pull{
    my $archivo = shift;
    my $version = shift;
    my $checkL;
    my $checkR;
    my @arreglar;
    my $rep;

    if (defined($version)){
        print "error\n" unless (&versionOK($archivo,$version));
    }else{
        $version = &getVersion($archivo);
    }

    ($checkR,$rep,@arreglar) = &validarChecksum($archivo,$version);
    while ($checkR ne $checkL){
        &getFromRep($archivo,$version,$rep);
        $checkL = &checksum($archivo);
    }
    &arreglarRep($archivo,$version,@arreglar) if (@arreglar);
}

sub arreglarRep{
    my $archivo = shift;
    my $version = shift;
    my @replicas = @_;

    &send2rep($archivo,$version,@replicas);

}
# Rutina que calcula el checksum de un archivo
sub checksum{
    my $archivo = shift;
    my $checksum;
    eval{
        open(FILE, "/tmp/$archivo") or die "Can't find file $archivo\n";
        my $ctx = Digest::MD5->new;
        $ctx->addfile(*FILE);
        $checksum = $ctx->hexdigest;
        close(FILE);
    }; 
    return $checksum;
}

# Rutina que valida los checksum del archivo en todas las replicas
# Retorna el checksum valido y la replica a solicitar
# Si existe un error en alguno de los checksum reenvia el archivo a 
# la replica con el checksum incorrecto
sub validarChecksum{
    my $archivo = shift;
    my $version = shift;
    my ($v,$c,@replicas) =  &getRep($archivo);
    my %checksums;
    shift @replicas;
    foreach(@replicas){
        my $rep_url = "http://$_:" . REP_PRC_PORT . '/RPC2';
        my $rep = Frontier::Client->new(url => $rep_url);
        my $result = $rep->call('rep.checksum',$archivo,$version);
        push (@{$checksums{$result}},$_);
    }

    my @modaCheck;
    my $moda;
    my @arreglar;
    while(my($check,@rep) = each %checksums){
        if (@modaCheck < @rep){
            if (@modaCheck){
                push(@arreglar,$_) foreach @modaCheck;
            }
            ($moda,@modaCheck) = ($check,@rep);
        }
    }
    return($moda,$modaCheck[0],@arreglar);
}

sub notificarCommit{
    my $archivo = shift;
    my $version = shift;
    my @reps = @_;
    
    print "Notificando commit al grupo multicast\n" if DEBUG;
    my $socket = IO::Socket::Multicast->new(PeerAddr=>MC_DESTINATION);
    my $datos  = "2,";
    $datos .= $archivo . ",";
    $datos .= $version . ",";
    $datos .= "@reps";
    $socket->send($datos) || die "No se pudo notificar al grupo: $!";
    print "Notificacion enviada al grupo multicast\n" if DEBUG;
}

# Rutina que envia un archivo a la replica
# Parametros
# @servidores: lista de los servidores a los que se enviara el archivo
# $archivo: achivo que se enviara
sub send2rep{
    my $archivo = shift;
    my $version = shift;
    my @reps = @_;
    my @pids;
    foreach(@reps){
        print "Enviando $archivo a $_";
        my $host = $_;
        my $sftp = Net::SFTP::Foreign->new(host=>$_, user=>'javier');
        $sftp->mkdir($raiz/$archivo);
        $sftp->put("/tmp/$archivo","$raiz/$archivo/$version");
        push(@pids,$pidRep{$_});
    }
    #   NOTIFICAR A TODO EL MUNDO EL ENVIO DE ARCHIVOS
    #   PARA QUE ACTUALICEN SU TABLA
    my $checksum = &checksum($archivo);
    &notificarCommit($archivo,$version,$checksum,@pids);
}

# Rutina que recibe un archivo de una replica
# Parametros
# $archivo
# $version (la ultima por defecto)
# $replica
sub getFromRep{
    my $archivo = shift;
    my $rep = shift;
    my $version = shift;
    $version = &getVersion($archivo) unless defined($version);
    my $sftp = Net::SFTP::Foreign->new(host=>$rep, user=>'javier');
    $sftp->get("$raiz/$archivo/$version","/tmp/$archivo");

}

# Rutina que busca las replicas que tienen un archivo dado y la ultima version
# disponible 
sub getRep{
    my $archivo = shift;
    my $version = 0;
    my @replicas;
    my $checksum;
    while (my($pid, $rep) = each %tablaNodos) {
        my $arch = $rep->get($archivo); 
        if (defined($arch)){
            push(@replicas,$rep->nombre);
            $version = $arch->contar_versiones;
            $checksum = $arch->get_version($version);
        }
        @replicas = &lowRep if (!@replicas);
        return ($version,$checksum,@replicas);
    }
}

# Rutina que busca las k replicas con menos carga
#
sub lowRep{
    my %cp;
    my @replicas;
    while (my($pid, $rep) = each %tablaNodos) {
        push (@{$cp{$rep->contar_archivos}},$rep->nombre);
    }  
    my @cargas = (sort keys %cp);
    
    my $krep = 0;
    my $key = shift @cargas;
    while ($krep < K){
        $key = shift @cargas unless ($cp{$key});
        push(@replicas, shift @{$cp{$key}});
        $krep++;
    }
    return @replicas;
}

# Rutina que retorna la ultima version de un archivo
sub getVersion{
    my $archivo = shift;
    my $version;
    while (my($pid, $rep) = each %tablaNodos) {
        my $arch = $rep->buscar_archivo($archivo); 
        if (defined($arch)){
            $version = $arch->contar_versiones();
            last;
        }
        return $version;
    }
}

#########
#Replica
#########
#

sub crearRaiz{
    mkdir $raiz;
}

sub wipe{
    system("rm -rf $raiz");
    &crearRaiz;
}

sub checksumRep{
    my $archivo = shift;
    my $version = shift;
    my $checksum;
    eval{
        open(FILE, "$raiz/$archivo") or die "Can't find file $archivo\n";
        my $ctx = Digest::MD5->new;
        $ctx->addfile(*FILE);
        $checksum = $ctx->hexdigest;
        close(FILE);
    }; 
    return $checksum;
}